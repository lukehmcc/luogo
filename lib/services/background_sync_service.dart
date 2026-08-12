import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:luogo/main.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackgroundSyncService {
  @pragma('vm:entry-point')
  static void backgroundFetchHeadlessTask(HeadlessTask event) async {
    String taskId = event.taskId;
    bool isTimeout = event.timeout;
    if (isTimeout) {
      logger.e("[BackgroundFetch] Headless task timed out: $taskId");
      BackgroundFetch.finish(taskId);
      return;
    }
    logger.i('[BackgroundFetch] Headless event received.');

    // Initialize logger for headless task since main() isn't called
    try {
      logger = Logger(
        printer: PrettyPrinter(dateTimeFormat: DateTimeFormat.dateAndTime),
        output: MultiOutput([
          AdvancedFileOutput(
            path: p.join((await getApplicationSupportDirectory()).path, "log"),
          ),
          ConsoleOutput(),
        ]),
      );
      await runBackgroundSync(taskId);
    } catch (e) {
      debugPrint("[BackgroundFetch] Headless task failed: $e");
    }

    BackgroundFetch.finish(taskId);
  }

  static Future<void> runBackgroundSync(String taskId) async {
    logger.i("[BackgroundFetch] Sync started for task: $taskId");
    try {
      LocationService? locationService;
      try {
        locationService = GetIt.I<LocationService>();
      } catch (e) {
        logger.d("LocationService not in GetIt, initializing for background");
      }

      locationService ??= await LocationService.initializeForBackground();

      // Fail fast when the relay (or network) is down: burning the iOS ~30s
      // budget on per-group connection timeouts gets future fetch grants
      // throttled by the OS.
      final RelayClient? relay = locationService.relayClient;
      if (relay == null || !await relay.isReachable()) {
        logger.w("[BackgroundFetch] Relay unreachable, skipping sync");
        return;
      }

      // Pull before push: there's no live WebSocket in this isolate, so
      // anything peers sent while we were dead must be fetched here or the
      // pins stay stale until the app reopens. fetchGroups falls back to
      // cache; resyncAll catches per-group failures.
      await relay.fetchGroups();
      await relay.resyncAll();

      await locationService.sendLocationUpdateOneShot();

      // Give incoming-message listeners a moment to finish. Keep it short:
      // iOS grants roughly 30s per task and overrunning throttles us.
      await Future.delayed(const Duration(seconds: 3));

      // Remember the last successful sync so the settings screen can show it.
      try {
        await locationService.prefs.setString(
            'last-background-sync', DateTime.now().toIso8601String());
      } catch (e) {
        logger.e("Failed to record background sync time: $e");
      }

      logger.i("Background sync completed successfully");
    } catch (e) {
      logger.e("Background sync failed: $e");
    }
  }

  static Future<void> configure() async {
    // Initialize background fetch
    await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15, // iOS minimum
          stopOnTerminate: false, // Allow Android to survive termination
          enableHeadless: true, // Enable Android headless mode
          startOnBoot: true, // Start on boot for Android
          // Use AlarmManager (exact) instead of JobScheduler batching, which
          // Doze/App Standby can defer for hours. Ignored on iOS.
          forceAlarmManager: true,
          requiredNetworkType: NetworkType.ANY,
        ), (taskId) async {
      await runBackgroundSync(taskId);
      BackgroundFetch.finish(taskId);
    }, (taskId) async {
      logger.e("[BackgroundFetch] Task timed out: $taskId");
      BackgroundFetch.finish(taskId);
    });

    // Register headless task
    BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  }
}
