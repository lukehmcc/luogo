import 'package:luogo/services/sync_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One measured gap between two consecutive relay syncs.
class NerdStatsInterval {
  final String source;
  final DateTime at;
  final Duration interval;

  const NerdStatsInterval({
    required this.source,
    required this.at,
    required this.interval,
  });
}

/// Aggregated stats for a single sync- trigger source (periodic / significant).
class NerdStatsBySource {
  final int count;
  final Duration average;

  const NerdStatsBySource({required this.count, required this.average});
}

/// Snapshot of the persisted sync history for the Nerd Stats diagnostics page.
class NerdStatsState {
  /// All stored entries (oldest → newest, up to 101).
  final List<SyncHistoryEntry> entries;

  /// Up to 10 most-recent intervals (newest first) with source labels.
  final List<NerdStatsInterval> recent;

  /// How many intervals we have (entries minus one, capped at 100).
  final int intervalCount;

  /// Average of all interval durations, or null when < 2 entries.
  final Duration? averageInterval;

  /// Per-source breakdown (periodic / significant / …).
  final Map<String, NerdStatsBySource> bySource;

  const NerdStatsState({
    this.entries = const [],
    this.recent = const [],
    this.intervalCount = 0,
    this.averageInterval,
    this.bySource = const {},
  });

  bool get hasData => entries.isNotEmpty && intervalCount > 0;

  /// Synchronously reads and computes all stats from prefs.
  static NerdStatsState compute(SharedPreferencesWithCache prefs) {
    final entries = SyncHistory.load(prefs);

    // Build intervals: entry i produces one interval using entry i‑1 as start.
    final intervals = <NerdStatsInterval>[];
    for (int i = 1; i < entries.length; i++) {
      intervals.add(NerdStatsInterval(
        source: entries[i].source,
        at: entries[i].ts,
        interval: entries[i].ts.difference(entries[i - 1].ts),
      ));
    }

    // Newest intervals first, capped at 10.
    final recent = intervals.reversed.take(10).toList();

    // Average over all intervals.
    Duration? averageInterval;
    if (intervals.isNotEmpty) {
      final totalMs =
          intervals.fold<int>(0, (sum, it) => sum + it.interval.inMilliseconds);
      averageInterval = Duration(milliseconds: totalMs ~/ intervals.length);
    }

    // Per-source grouping.
    final grouped = <String, List<Duration>>{};
    for (final it in intervals) {
      grouped.putIfAbsent(it.source, () => []).add(it.interval);
    }
    final bySource = <String, NerdStatsBySource>{};
    grouped.forEach((source, list) {
      final totalMs = list.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
      bySource[source] = NerdStatsBySource(
        count: list.length,
        average: Duration(milliseconds: totalMs ~/ list.length),
      );
    });

    return NerdStatsState(
      entries: entries,
      recent: recent,
      intervalCount: intervals.length,
      averageInterval: averageInterval,
      bySource: bySource,
    );
  }

  /// Formats a [Duration] as "1h 05m 32s" / "05m 32s" / "42s".
  static String formatDuration(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes % 60;
    final int s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) {
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${s}s';
  }
}
