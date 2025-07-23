import 'package:hive_ce/hive.dart';
import 'package:luogo/model/hive_latlng.dart';

/// Represents a user's local state with coordinates, timestamp, name, and color.
///
/// Example:
/// ```dart
/// final userState = UserState(
///   coords: HiveLatLng(lat: 37.7749, lng: -122.4194),
///   ts: DateTime.now().millisecondsSinceEpoch,
///   name: "John Doe",
///   color: 0xFF0000,
/// );
/// ```
class UserState extends HiveObject {
  final HiveLatLng coords;
  final int ts; // Timestamp when last updated
  final String name;
  final int color;
  UserState(
      {required this.coords,
      required this.ts,
      required this.name,
      required this.color});

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(ts);

  @override
  String toString() =>
      'UserState(coords: $coords, ts: $ts, name: $name, color: $color)';
}
