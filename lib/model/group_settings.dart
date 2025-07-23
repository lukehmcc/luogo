import 'dart:convert';

import 'package:luogo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A class for managing group-specific settings that are persisted in SharedPreferences.
///
/// This class handles the serialization and deserialization of group settings,
/// including location sharing preferences.
///
/// Example usage:
/// ```dart
/// // Load settings for a group
/// final settings = GroupSettings.load(group, prefs);
///
/// // Update and save settings
/// settings.shareLocation = false;
/// await GroupSettings.save(prefs, settings);
///
/// // Create new settings
/// final newSettings = GroupSettings(
///   groupId: groupId;,
///   shareLocation: true,
/// );
/// ```
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
  static GroupSettings load(String groupId, SharedPreferencesWithCache prefs) {
    final String? jsonString = prefs.getString(groupId);
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
    SharedPreferencesWithCache prefs,
    GroupSettings settings,
  ) async {
    await prefs.setString(
      settings.groupId,
      jsonEncode(settings.toJson()),
    );
  }
}
