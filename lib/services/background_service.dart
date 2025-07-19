import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:luogo/services/location_service.dart';

const String backgroundLocationTask = "backgroundLocationTask";
final Logger logger = Logger();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backgroundLocationTask) {
      logger.d("Running background location task!");
      try {
        // This is a simplified, one-shot version of your initialization.
        // It must be self-contained.
        final locationService = await LocationService.initializeForBackground();
        await locationService.sendLocationUpdateOneShot();
        logger.d("Background task complete.");
        return Future.value(true);
      } catch (e) {
        logger.d("Error in background task: $e");
        return Future.value(false);
      }
    }
    return Future.value(false);
  });
}
