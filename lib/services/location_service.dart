import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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

  /// Call this to start periodic location updates.
  Future<void> startPeriodicUpdates({int intervalSeconds = 5}) async {
    // Check permissions first
    locationBox = await Hive.openBox('location');
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    // Fetch immediately
    _fetchLocation();

    // Watch for continuing location updates
    Geolocator.getPositionStream().listen((Position position) {
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      logger.d("NEW POSITION: $position");
      locationBox.put('local_position', HiveLatLng.fromLatLng(latLng));
    });
  }

  // Internal location fetcher for oneshots
  Future<void> _fetchLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng latLng = LatLng(position.latitude, position.longitude);
      logger.d(position);
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

  void dispose() {
    _timer?.cancel();
  }
}
