import 'dart:convert';

import 'package:luogo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One recorded relay sync, kept so the Nerd Stats page can show intervals.
class SyncHistoryEntry {
  final DateTime ts;
  final String source;

  const SyncHistoryEntry({required this.ts, required this.source});

  Map<String, dynamic> toJson() => {'ts': ts.toIso8601String(), 'source': source};

  factory SyncHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SyncHistoryEntry(
        ts: DateTime.parse(json['ts'] as String),
        source: json['source'] as String? ?? 'periodic',
      );
}

/// Persists the last successful syncs (timestamp + trigger source) so
/// intervals between them can be computed. Capped so it never grows:
/// [maxEntries] timestamps yield at most [maxEntries - 1] intervals.
class SyncHistory {
  static const String _key = 'sync-history';
  static const int maxEntries = 101;

  /// Appends a completed sync. Best-effort; a failure only loses one entry.
  static Future<void> record(
      SharedPreferencesWithCache prefs, String source) async {
    final List<SyncHistoryEntry> entries = load(prefs)
      ..add(SyncHistoryEntry(ts: DateTime.now(), source: source));
    while (entries.length > maxEntries) {
      entries.removeAt(0);
    }
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// Oldest → newest recorded syncs.
  static List<SyncHistoryEntry> load(SharedPreferencesWithCache prefs) {
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => SyncHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e("Failed to decode sync history: $e");
      return [];
    }
  }
}