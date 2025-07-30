import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/hive/hive_registrar.g.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_settings.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:luogo/model/message_embed.dart';
import 'package:luogo/model/user_state.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:s5/s5.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

/// A service for periodically fetching and storing the device's current location.
///
/// ## Usage
/// ```dart
/// final locationService = LocationService();
/// await locationService.startPeriodicUpdates(intervalSeconds: 10);
/// // Remember to call dispose() when done
/// ```
class LocationService {
  // Passed in vars
  final SharedPreferencesWithCache prefs;

  LocationService({required this.prefs});

  // Later initialized vars
  Timer? _timer;
  late Box<HiveLatLng> locationBox;
  late Box<UserState> userStateBox;
  S5Messenger? s5messenger;
  Map<String, StreamSubscription<dynamic>> groupListeners =
      <String, StreamSubscription<dynamic>>{};
  final Uuid _uuid = Uuid();
  String? myID;

  /// Call this to start periodic location updates.
  /// Currently using live updates, not the intervals
  Future<void> startPeriodicUpdates({int intervalSeconds = 5}) async {
    // Check permissions first
    locationBox = await Hive.openBox<HiveLatLng>('location');
    userStateBox = await Hive.openBox<UserState>('userState');
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      logger.e("Location Permissions are not allowed!");
      return;
    }

    // To not flood the channel with messages, just ping every minuet
    LatLng? lastSentPosition;
    _timer = Timer.periodic(Duration(minutes: 1), (timer) async {
      if (lastSentPosition != null) {
        await _updatePeers(lastSentPosition!);
      }
    });

    // Watch for continuing location updates
    Geolocator.getPositionStream().listen((Position position) async {
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      lastSentPosition = latLng;
      locationBox.put('local_position', HiveLatLng.fromLatLng(latLng));
    });
  }

  // static initializer for the background task
  static Future<LocationService> initializeForBackground() async {
    // Initialize dependencies just like in MainCubit
    final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions());

    await RustLib.init();
    final Directory dir = await getApplicationSupportDirectory();
    Hive
      ..init(path.join(dir.path, 'hive'))
      ..registerAdapters();

    final service = LocationService(prefs: prefs);

    service.locationBox = await Hive.openBox<HiveLatLng>('location');
    service.userStateBox = await Hive.openBox<UserState>('userState');

    final s5 = await S5.create(
      persistFilePath: path.join(
          (await getApplicationDocumentsDirectory()).path, 'persist.json'),
    );
    final s5messenger = S5Messenger();
    await s5messenger.init(s5);
    service.setS5Messenger(s5messenger);

    return service;
  }

  // A oneshot, non-continuous way to send location updates
  Future<void> sendLocationUpdateOneShot() async {
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      logger.w("Background task: No location permission.");
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      await _updatePeers(latLng);
    } catch (e) {
      logger.e('Error fetching/sending location in background: $e');
    }
  }

  // Internal location fetcher for oneshots
  Future<void> _fetchLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      locationBox.put('local_position', HiveLatLng.fromLatLng(latLng));
      logger.d("Local Position: ${latLng.longitude}, ${latLng.latitude}");
    } catch (e) {
      logger.e('Error fetching location: $e');
    }
  }

  // Checks & ensures permissions are granted
  // returns true if position granted
  Future<bool> _checkLocationPermission() async {
    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    // If permission is denied and we haven't asked before, request it
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Now that location has been allowed (hopefully), we fetch location to
    // update the map
    await _fetchLocation();

    // Return true only if permission is granted (while or after asking)
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // Quick peer pinger function
  void pingPeers() {
    // get location from hive, then send it to peers
    final LatLng? loc = locationBox.get('local_position')?.toLatLng();
    if (loc != null) {
      _updatePeers(loc);
    }
  }

  void setS5Messenger(S5Messenger inMessenger) {
    s5messenger = inMessenger;
    // Set you ID so it can be used later
    myID = (s5messenger!.dataBox.get('identity_default')
        as Map<dynamic, dynamic>)['publicKey'];
    _initializeGroupListeners();
  }

  void _initializeGroupListeners() async {
    // gotta wait here for the groups to populate, then you can add the subscriptions
    while (s5messenger!.groups.isEmpty) {
      await Future.delayed(Duration(milliseconds: 250));
    }
    // Set a listener for each group then start listening for updates of location
    for (final GroupState group in s5messenger!.groups.values) {
      logger.d("Setting up listener for: ${group.groupId}");
      setupListenToPeer(group);
    }
  }

  // Standard way to begin listening to a peer and add subscription
  void setupListenToPeer(GroupState group) {
    logger.d("Listening for group ${group.groupId}");

    // Add the subscription to the set
    final subscription = group.messageListStateNotifier.stream.listen((_) {
      final TextMessage message =
          (group.messagesMemory.first.msg as TextMessage);
      // Skip message if from self
      if (message.senderId == myID) {
        return;
      }
      logger.d("Message incoming!");
      if (message.embed != null) {
        logger.d("And it has an embed");
        final MessageEmbed messageEmbed =
            MessageEmbed.fromMsgpack(message.embed!);
        // Create user state then push it to hive
        final UserState newUserState = UserState(
          coords: HiveLatLng(
              lat: messageEmbed.coordinates.latitude,
              long: messageEmbed.coordinates.longitude),
          ts: DateTime.now().millisecondsSinceEpoch,
          name: messageEmbed.name,
          color: messageEmbed.color.toARGB32(),
        );

        userStateBox.put(message.senderId, newUserState);

        logger.d(
            "Just Put ${message.senderId}:\nCoords: ${messageEmbed.coordinates.latitude}, ${messageEmbed.coordinates.longitude}\nColor: ${messageEmbed.color}\nUsername: ${messageEmbed.name}");
      } else {
        logger.d("Message had no geo embed");
      }
    });
    groupListeners[group.groupId] = subscription;
  }

  // On every location update, this guy'll check which groups are good to ping,
  // then send them the locaiton
  Future<void> _updatePeers(LatLng latLng) async {
    final Uint8List messageEmbedBytes =
        MessageEmbed.fromPrefs(latLng, prefs, null).toMsgpack();
    // Will run all the time, but won't actually do anything if s5Messenger isn't ready
    if (s5messenger != null) {
      for (final MapEntry<String, GroupState> group
          in s5messenger!.groups.entries) {
        GroupSettings groupSettings = GroupSettings.load(group.key, prefs);
        // Now if the location should be shared, share the current location
        if (groupSettings.shareLocation == true && myID != null) {
          // grab ID
          s5messenger!.group(group.key).sendMessage(
                "location update",
                messageEmbedBytes,
                myID!,
                _uuid.v4(),
              );
          logger.d("sent location");
        }
      }
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
