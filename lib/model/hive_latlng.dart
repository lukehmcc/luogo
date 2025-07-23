import 'package:hive_ce/hive.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A Hive-adapted object for storing geographic coordinates (latitude and longitude).
///
/// This class provides conversion utilities between [HiveLatLng] and [LatLng] (from maplibre_gl),
/// allowing seamless interoperability between Hive storage and MapLibre GL's coordinate system.
///
/// Example:
/// ```dart
/// final hiveCoords = HiveLatLng(lat: 37.7749, long: -122.4194);
/// final mapCoords = hiveCoords.toLatLng(); // Convert to MapLibre's LatLng
/// ```
class HiveLatLng extends HiveObject {
  double lat;
  double long;

  HiveLatLng({required this.lat, required this.long});

  factory HiveLatLng.fromLatLng(LatLng latLng) {
    return HiveLatLng(lat: latLng.latitude, long: latLng.longitude);
  }

  LatLng toLatLng() {
    return LatLng(lat, long);
  }

  @override
  String toString() {
    return 'HiveLatLng(latty: $lat, longy: $long)';
  }
}
