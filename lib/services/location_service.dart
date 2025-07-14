import 'dart:async';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_settings.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service for periodically fetching and storing the device's current location.
///
/// This service handles:
/// - **Permission management**: Checks and requests location permissions
/// - **Periodic updates**: Fetches location at configurable intervals
/// - **Persistence**: Stores locations using Hive for offline access
///
/// ## Usage
/// ```dart
/// final locationService = LocationService();
/// await locationService.startPeriodicUpdates(intervalSeconds: 10);
/// // Remember to call dispose() when done
/// ```
class LocationService {
  Timer? _timer;
  late Box<HiveLatLng> locationBox;
  final SharedPreferences prefs;
  S5Messenger? s5messenger;

  LocationService({required this.prefs});

  /// Call this to start periodic location updates.
  /// Currently using live updates, not the intervals
  Future<void> startPeriodicUpdates({int intervalSeconds = 5}) async {
    // Check permissions first
    locationBox = await Hive.openBox('location');
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    // Fetch immediately
    _fetchLocation();

    // Watch for continuing location updates
    Geolocator.getPositionStream().listen((Position position) async {
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      locationBox.put('local_position', HiveLatLng.fromLatLng(latLng));
      await _updatePeers(latLng);
    });
  }

  // Internal location fetcher for oneshots
  Future<void> _fetchLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      locationBox.put('local_position', HiveLatLng.fromLatLng(latLng));
    } catch (e) {
      logger.e('Error fetching location: $e');
    }
  }

  // Checks & ensures permissions are granted
  // returns true if position granted
  Future<bool> _checkLocationPermission() async {
    final bool hasAskedBefore =
        prefs.getBool('hasAskedLocationPermission') ?? false;

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    // If permission was denied before, don't ask again
    if (hasAskedBefore && permission == LocationPermission.denied) {
      return false;
    }

    // If permission is denied and we haven't asked before, request it
    if (permission == LocationPermission.denied && !hasAskedBefore) {
      permission = await Geolocator.requestPermission();
      // Mark that we've asked, regardless of the user's choice
      await prefs.setBool('hasAskedLocationPermission', true);
    }

    // Now that location has been allowed (hopefully), we fetch location to
    // update the map
    await _fetchLocation();

    // Return true only if permission is granted (while or after asking)
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  void setS5Messenger(S5Messenger inMessenger) {
    s5messenger = inMessenger;
    // TODO move this listener to somewhere better
    // Set a listener for each group then start listening for updates of location
    for (final GroupState group in s5messenger!.groups.values) {
      group.messageListStateNotifier.stream.listen((_) {
        final TextMessage message =
            (group.messagesMemory.first.msg as TextMessage);
        if (message.embed != null) {
          logger.d(
              "Decode coords: ${_decodeLatLng(message.embed!).latitude}, ${_decodeLatLng(message.embed!).longitude}");
        } else {
          logger.d("Message had no geo embed");
        }
      });
    }
  }

  // On every location update, this guy'll check which groups are good to ping,
  // then send them the locaiton
  Future<void> _updatePeers(LatLng latLng) async {
    Uint8List locationBytes = _latLngToMsgpack(latLng);
    // Will run all the time, but won't actually do anything if s5Messenger isn't ready
    if (s5messenger != null) {
      for (final MapEntry<String, GroupState> group
          in s5messenger!.groups.entries) {
        GroupSettings groupSettings = GroupSettings.load(group.key, prefs);
        // Now if the location should be shared, share the current location
        if (groupSettings.shareLocation == true) {
          s5messenger!
              .group(group.key)
              .sendMessage("location update", locationBytes);
        }
      }
    }
  }

  LatLng _decodeLatLng(Uint8List msgpackBytes) {
    final List<dynamic> coordinates = deserialize(msgpackBytes);
    return LatLng(coordinates[0] as double, coordinates[1] as double);
  }

  Uint8List _latLngToMsgpack(LatLng latLng) {
    return serialize([latLng.latitude, latLng.longitude]);
  }

  void dispose() {
    _timer?.cancel();
  }
}
