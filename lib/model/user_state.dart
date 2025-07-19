import 'package:hive_ce/hive.dart';
import 'package:luogo/model/hive_latlng.dart';

/// This object defines the local state for each user which is stored in hive on update
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
