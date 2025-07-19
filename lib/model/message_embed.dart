import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageEmbed {
  final LatLng coordinates;
  final String name;
  final Color color;
  final String? newGroupName;

  MessageEmbed(
      {required this.coordinates,
      required this.name,
      required this.color,
      this.newGroupName});

  // Serialize to MessagePack (Uint8List)
  Uint8List toMsgpack() {
    return serialize({
      'coordinates': [coordinates.latitude, coordinates.longitude],
      'name': name,
      'color': color.toARGB32(),
      'newGroupName': newGroupName,
    });
  }

  // Deserialize from MessagePack (Uint8List)
  factory MessageEmbed.fromMsgpack(Uint8List msgpackBytes) {
    final Map<dynamic, dynamic> data = deserialize(msgpackBytes);
    final List<dynamic> coords = data['coordinates'];

    return MessageEmbed(
      coordinates: LatLng(coords[0] as double, coords[1] as double),
      name: data['name'],
      color: Color(data['color'] ?? 0),
      newGroupName: data['newGroupName'],
    );
  }

  // Helper constructor from preferences
  factory MessageEmbed.fromPrefs(LatLng coordinates,
      SharedPreferencesWithCache prefs, String? newGroupName) {
    return MessageEmbed(
      coordinates: coordinates,
      name: prefs.getString('name') ?? "",
      color: Color(prefs.getInt('color') ?? 0),
      newGroupName: newGroupName,
    );
  }
}
