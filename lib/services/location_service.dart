// lib/services/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:luogo/main.dart';

class LocationService {
  Timer? _timer;
  late Box<Position> locationBox;

  Future<void> startPeriodicUpdates({int intervalMinutes = 5}) async {
    // Check permissions first
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;
    locationBox = await Hive.openBox('location');

    // Fetch immediately, then every `intervalMinutes`
    _fetchLocation();
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _fetchLocation(),
    );
  }

  Future<void> _fetchLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      logger.d(position);
      locationBox.put('local_position', position);
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

    // Return true only if permission is granted (while or after asking)
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  void dispose() {
    _timer?.cancel();
  }
}
