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
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/services/relay_setup.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

/// A service for periodically fetching the device's current location and
/// routing it to group members through the relay.
///
/// Outgoing positions are encrypted end-to-end with the per-group key
/// ([GroupCrypto]); incoming relay messages are decrypted and written to
/// [userStateBox], which the UI watches for live map pins.
class LocationService {
  // Passed in vars
  final SharedPreferencesWithCache prefs;

  LocationService({required this.prefs});

  // Later initialized vars
  Timer? _timer;
  late Box<HiveLatLng> locationBox;
  late Box<UserState> userStateBox;
  RelayClient? relayClient;
  GroupCrypto? crypto;
  StreamSubscription<RelayEvent>? _relaySubscription;
  String? myID;

  // Inits the location service
  Future<void> init() async {
    locationBox = await Hive.openBox<HiveLatLng>('location');
    userStateBox = await Hive.openBox<UserState>('userState');
  }

  /// Call this to start periodic location updates.
  /// Currently using live updates, not the intervals
  Future<bool> startPeriodicUpdates({int intervalSeconds = 5}) async {
    // Check permissions first
    bool hasPermission = await checkLocationPermissions();
    if (!hasPermission) {
      logger.e("Location Permissions are not allowed!");
      return false;
    }

    // To not flood the channel with messages, just ping every minute
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
  // Lightweight: no native/runtime init, just prefs + Hive + a relay client.
  static Future<LocationService> initializeForBackground() async {
    final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions());

    final Directory dir = await getApplicationSupportDirectory();
    Hive.init(path.join(dir.path, 'hive'));
    // The app isolate may have registered these already; registering twice
    // throws, so only do it when needed.
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }

    final service = LocationService(prefs: prefs);
    service.locationBox = await Hive.openBox<HiveLatLng>('location');
    service.userStateBox = await Hive.openBox<UserState>('userState');

    final relaySetup = await initRelayAndCrypto(prefs);
    service.setRelayClient(relaySetup.relay, relaySetup.crypto);

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
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      logger.d("Attempting to update peers");
      await _updatePeers(latLng);
      logger.d("Updated peers");
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
  Future<bool> checkLocationPermissions() async {
    logger.d("Checking location permissions");
    LocationPermission permission = await Geolocator.checkPermission();

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

  Future<bool> askForLocationPermissions() async {
    logger.d("Requesting Location Permissions");
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Wires the relay in: sets our identity and starts decrypting incoming
  /// messages into [userStateBox]. The relay may still be unauthenticated
  /// (server unreachable); [myID] stays null until it recovers.
  void setRelayClient(RelayClient relay, GroupCrypto groupCrypto) {
    relayClient = relay;
    crypto = groupCrypto;
    myID = relay.isAuthenticated ? relay.userId : null;
    _relaySubscription?.cancel();
    _relaySubscription = relay.events.listen(_handleRelayEvent);
  }

  void _handleRelayEvent(RelayEvent event) {
    if (event is RelayHelloEvent) {
      // Relay (re)connected — adopt our server-assigned id.
      myID = event.userId;
      logger.d("Relay hello, myID=$myID");
    } else if (event is RelayMessageEvent) {
      _handleIncomingMessage(event.message);
    } else if (event is RelayMemberEvent) {
      logger.d("Member ${event.userId} ${event.action} in ${event.groupId}");
    }
  }

  // Decrypts an incoming location message and pushes it to the UI layer.
  Future<void> _handleIncomingMessage(RelayMessage message) async {
    // Skip messages we sent ourselves
    if (message.senderId == myID) {
      return;
    }
    final GroupCrypto? groupCrypto = crypto;
    if (groupCrypto == null) return;
    final Map<String, dynamic>? payload =
        await groupCrypto.decrypt(message.groupId, message.ciphertext);
    final MessageEmbed? messageEmbed =
        payload == null ? null : MessageEmbed.fromJson(payload);
    if (messageEmbed == null) {
      logger.d("Message from ${message.senderId} failed to decrypt");
      return;
    }
    // Update the user's location
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

    // If there's a new group chat name, apply it locally
    if (messageEmbed.newGroupName != null) {
      // Replaced by server-side renames; kept for forward compatibility.
      logger.d("Ignoring legacy group rename propagation");
    }
  }

  // On every location update, this guy'll check which groups are good to ping,
  // then send them the encrypted location
  Future<void> _updatePeers(LatLng latLng) async {
    final RelayClient? relay = relayClient;
    final GroupCrypto? groupCrypto = crypto;
    if (relay == null || groupCrypto == null || myID == null) {
      logger.d("Relay not ready, skipping location update");
      return;
    }
    // Will run all the time, but won't actually do anything if the relay isn't ready
    for (final RelayGroup group in relay.groups) {
      GroupSettings groupSettings = GroupSettings.load(group.id, prefs);
      if (groupSettings.shareLocation == true) {
        final Uint8List ciphertext =
            await groupCrypto.encrypt(group.id, _embedFor(latLng));
        try {
          final RelayMessage acked = await relay.sendMessage(group.id, ciphertext);
          logger.d("sent location (seq ${acked.seq})");
        } catch (e) {
          logger.e("Failed to send location to ${group.id}: $e");
        }
      }
    }
  }

  Map<String, dynamic> _embedFor(LatLng latLng) {
    return MessageEmbed.fromPrefs(latLng, prefs, null).toJson();
  }

  void dispose() {
    _timer?.cancel();
    _relaySubscription?.cancel();
  }
}
