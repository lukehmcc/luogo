import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:luogo/main.dart';
import 'package:luogo/services/location_service.dart';

class BackgroundSyncService {
  @pragma('vm:entry-point')
  static void backgroundFetchHeadlessTask(HeadlessEvent event) async {
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
      logger = Logger(printer: PrettyPrinter());
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

      locationService.initializeGroupListeners();
      await locationService.sendLocationUpdateOneShot();

      // Give some time for incoming messages to be processed
      // On iOS we have about 30 seconds total, on Android it's more flexible
      await Future.delayed(const Duration(seconds: 15));

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
