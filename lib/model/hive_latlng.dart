import 'package:hive_ce/hive.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Dedicated Hive object for storing latitude and longitude.
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
