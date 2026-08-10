import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A class representing an embeddable message with geographic coordinates and
/// styling. Serialized as JSON and then encrypted client-side with the group
/// key; the relay only ever sees the ciphertext.
class MessageEmbed {
  final LatLng coordinates;
  final String name;
  final Color color;
  final String? newGroupName;
  final int timestamp;

  MessageEmbed({
    required this.coordinates,
    required this.name,
    required this.color,
    this.newGroupName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'coordinates': [coordinates.latitude, coordinates.longitude],
        'name': name,
        'color': color.toARGB32(),
        'newGroupName': newGroupName,
        'timestamp': timestamp,
      };

  factory MessageEmbed.fromJson(Map<String, dynamic> data) {
    final List<dynamic> coords = data['coordinates'] as List<dynamic>;
    return MessageEmbed(
      coordinates: LatLng(coords[0] as double, coords[1] as double),
      name: data['name'] as String? ?? "",
      color: Color(data['color'] as int? ?? 0),
      newGroupName: data['newGroupName'] as String?,
      timestamp:
          data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Helper constructor from preferences
  factory MessageEmbed.fromPrefs(
      LatLng coordinates, SharedPreferencesWithCache prefs, String? newGroupName) {
    return MessageEmbed(
      coordinates: coordinates,
      name: prefs.getString('name') ?? "",
      color: Color(prefs.getInt('color') ?? 0),
      newGroupName: newGroupName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Uint8List toJsonBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  static MessageEmbed? fromJsonBytes(Uint8List bytes) {
    try {
      return MessageEmbed.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}
