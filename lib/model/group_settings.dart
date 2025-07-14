import 'dart:convert';

import 'package:luogo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Defines group settings which are saved to prefs
class GroupSettings {
  final String groupId;
  bool shareLocation;

  GroupSettings({
    required this.groupId,
    required this.shareLocation,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'shareLocation': shareLocation,
      };

  // Create from JSON
  factory GroupSettings.fromJson(String groupId, Map<String, dynamic> json) =>
      GroupSettings(
        groupId: groupId,
        shareLocation: json['shareLocation'] ?? false,
      );

  // read
  // If not set, it defaults to true as this is a location sharing app
  static GroupSettings load(String groupId, SharedPreferences prefs) {
    final jsonString = prefs.getString(groupId);
    if (jsonString == null) {
      return GroupSettings(
          groupId: groupId, shareLocation: true); // No saved settings
    }

    try {
      return GroupSettings.fromJson(
        groupId,
        jsonDecode(jsonString), // Convert JSON string to Map
      );
    } catch (e) {
      logger.d('Error parsing settings: $e');
      return GroupSettings(groupId: groupId, shareLocation: true);
    }
  }

  // write
  static Future<void> save(
    SharedPreferences prefs,
    GroupSettings settings,
  ) async {
    await prefs.setString(
      settings.groupId,
      jsonEncode(settings.toJson()),
    );
  }
}
