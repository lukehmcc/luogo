import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:luogo/hive/hive_registrar.g.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_settings.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:luogo/model/message_embed.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/utils/check_s5_connectivity.dart';
import 'package:luogo/utils/s5_logger.dart';
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
  Map<String, List<StreamSubscription<dynamic>>> groupListeners =
      <String, List<StreamSubscription<dynamic>>>{};
  final Uuid _uuid = Uuid();
  String? myID;

  // Inits the locaiton service
  Future<void> init() async {
    locationBox = await Hive.openBox<HiveLatLng>('location');
    userStateBox = await Hive.openBox<UserState>('userState');
  }

  /// Call this to start periodic location updates.
  /// Currently using live updates, not the intervals
  /// Returns false if fails or true if sucsess
  Future<bool> startPeriodicUpdates({int intervalSeconds = 5}) async {
    // Check permissions first
    bool hasPermission = await checkLocationPermissions();
    if (!hasPermission) {
      logger.e("Location Permissions are not allowed!");
      return false;
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
    return true;
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
      initialPeers: [
        prefs.getString('s5-node') ?? '', // put the users s5 node first
        'wss://z2DeVYsXdq3Rgt8252LRwNnreAtsGr3BN6FPc6Hvg6dTtRk@s5.jptr.tech/s5/p2p',
        'wss://z2Das8aEF7oNoxkcrfvzerZ1iBPWfm6D7gy3hVE4ALGSpVB@node.sfive.net/s5/p2p',
        'wss://z2DdbxV4xyoqWck5pXXJdVzRnwQC6Gbv6o7xDvyZvzKUfuj@s5.vup.dev/s5/p2p',
        'wss://z2DWuWNZcdSyZLpXFK2uCU3haaWMXrDAgxzv17sDEMHstZb@s5.garden/s5/p2p',
      ],
      logger: SilentLogger(),
      persistFilePath: path.join(
          (await getApplicationDocumentsDirectory()).path, 'persist.json'),
    );
    final s5messenger = S5Messenger();
    await s5messenger.init(s5, path.join(dir.path, 'keystore.sqlite'));
    service.setS5Messenger(s5messenger);

    return service;
  }

  // A oneshot, non-continuous way to send location updates
  Future<void> sendLocationUpdateOneShot() async {
    logger.d("Current time: ${DateFormat('h:mm a').format(DateTime.now())}");
    // give it a couple seconds to catch up
    bool hasPermission = await checkLocationPermissions();
    if (!hasPermission) {
      logger.w("Background task: No location permission.");
      return;
    }

    try {
      // Wait for groups to be ready before sending
      int attempts = 0;
      while (s5messenger == null ||
          s5messenger!.groups.isEmpty && attempts < 20) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
      }

      final Position position = await Geolocator.getCurrentPosition();
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      logger.d("Attempting to update peers");
      await _updatePeers(latLng);
      logger.d("Updated peers");
    } catch (e) {
      logger.e('Error fetching/sending location in background: $e');
    }
  }

  // When renaming a group or syncing info to a new member, call this
  Future<void> sendGroupInfoUpdate(String groupID, String? newName,
      {String? message}) async {
    try {
      GroupSettings groupSettings = GroupSettings.load(groupID, prefs);
      LatLng sendLoc = const LatLng(0, 0);
      if (groupSettings.shareLocation == true) {
        sendLoc =
            locationBox.get('local_position')?.toLatLng() ?? const LatLng(0, 0);
      }

      final Uint8List messageEmbedBytes =
          MessageEmbed.fromPrefs(sendLoc, prefs, newName).toMsgpack();

      await _sendMessage(
          groupID, message ?? "Group renamed to $newName", messageEmbedBytes);
      logger.d("sent group info update for group $groupID");
    } catch (e) {
      logger.e('Error sending group info update: $e');
    }
  }

  // Checks & ensures permissions are granted
  // returns true if position granted
  Future<bool> checkLocationPermissions() async {
    // Check current permission status
    logger.d("Checking location permissions");
    LocationPermission permission = await Geolocator.checkPermission();

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

  Future<bool> askForLocationPermissions() async {
    logger.d("Requesting Location Permissions");
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    } else {
      return false;
    }
  }

  void setS5Messenger(S5Messenger inMessenger) {
    s5messenger = inMessenger;
    // Set you ID so it can be used later
    myID = (s5messenger!.dataBox.get('identity_default')
        as Map<dynamic, dynamic>)['publicKey'];
    initializeGroupListeners();
  }

  void initializeGroupListeners() async {
    // gotta wait here for the groups to populate, then you can add the subscriptions
    int attempts = 0;
    while (s5messenger!.groups.isEmpty && attempts < 20) {
      await Future.delayed(Duration(milliseconds: 250));
      attempts++;
    }

    if (s5messenger!.groups.isEmpty) {
      logger.d("No groups found after waiting.");
      return;
    }

    // For safety, make sure to dispose of any previous listeners
    groupListeners.forEach((_, subs) {
      for (final sub in subs) {
        sub.cancel();
      }
    });
    groupListeners.clear();

    // Set a listener for each group then start listening for updates of location
    for (final GroupState group in s5messenger!.groups.values) {
      logger.d("Setting up listener for: ${group.groupId}");
      setupListenToPeer(group);
    }
  }

  // Standard way to begin listening to a peer and add subscription
  void setupListenToPeer(GroupState group) {
    logger.d("Listening for group ${group.groupId}");

    // Listen for new members joining the group to immediately share our info with them
    final memberSub = group.membersStateNotifier.stream.listen((_) {
      logger.d("Members changed in group ${group.groupId}, sending update");
      final groupData = s5messenger?.groupsBox.get(group.groupId);
      sendGroupInfoUpdate(group.groupId, groupData?['name'],
          message: "info update");
    });

    // Add the subscription to the set
    final messageSub = group.messageListStateNotifier.stream.listen((_) {
      if (group.messagesMemory.isEmpty) {
        return;
      }
      final messageObj = group.messagesMemory.first.msg;
      if (messageObj is! TextMessage) {
        return;
      }
      final TextMessage message = messageObj;

      // Skip message if from self
      if (message.senderId == myID) {
        return;
      }
      logger.d("Message incoming!");
      if (message.embed != null) {
        logger.d("And it has an embed");
        // Update the user's locaiton
        final MessageEmbed messageEmbed =
            MessageEmbed.fromMsgpack(message.embed!);
        // Create user state then push it to hive
        final UserState newUserState = UserState(
          coords: HiveLatLng(
              lat: messageEmbed.coordinates.latitude,
              long: messageEmbed.coordinates.longitude),
          ts: messageEmbed.timestamp,
          name: messageEmbed.name,
          color: messageEmbed.color.toARGB32(),
        );

        userStateBox.put(message.senderId, newUserState);

        logger.d(
            "Just Put ${message.senderId}:\nCoords: ${messageEmbed.coordinates.latitude}, ${messageEmbed.coordinates.longitude}\nColor: ${messageEmbed.color}\nUsername: ${messageEmbed.name}");

        // Then if there's a new group chat name, deal with that as well
        if (messageEmbed.newGroupName != null) {
          final groupData = s5messenger?.groupsBox.get(group.groupId);
          if (groupData?['name'] != messageEmbed.newGroupName) {
            logger.d("Renaming group to ${messageEmbed.newGroupName}");
            group.rename(messageEmbed.newGroupName!);
            s5messenger?.messengerState.update();
          }
        }
      } else {
        logger.d("Message had no geo embed");
      }
    });
    groupListeners[group.groupId] = [memberSub, messageSub];
  }

  // On every location update, this guy'll check which groups are good to ping,
  // then send them the locaiton
  Future<void> _updatePeers(LatLng latLng) async {
    // before you do anything, test if s5 is online
    if (s5messenger?.s5 != null) {
      logger.d(
          "S5 is currently ${(await checkS5Online(s5messenger!.s5) ? "online" : "offline")}");
    }

    // Will run all the time, but won't actually do anything if s5Messenger isn't ready
    if (s5messenger != null) {
      for (final MapEntry<String, GroupState> group
          in s5messenger!.groups.entries) {
        GroupSettings groupSettings = GroupSettings.load(group.key, prefs);
        // Now if the location should be shared, share the current location
        if (groupSettings.shareLocation == true && myID != null) {
          final Uint8List messageEmbedBytes =
              MessageEmbed.fromPrefs(latLng, prefs, null).toMsgpack();
          await _sendMessage(group.key, "location update", messageEmbedBytes);
        }
      }
    }
  }

  // A internal helper to centralize the logic of sending a message
  Future<void> _sendMessage(
      String groupID, String text, Uint8List embedBytes) async {
    if (s5messenger != null && myID != null) {
      await s5messenger!.group(groupID).sendMessage(
            text,
            embedBytes,
            myID!,
            _uuid.v4(),
          );
      logger.d("sent message to group $groupID: $text");
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
