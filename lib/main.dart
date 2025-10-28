import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/init_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// This is my only global var, as no init process
late Logger logger;

/// Main fucntion that starts everything. Utilizes a Cubit to handle state
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Init logger to path if in prod
  String logPath = p.join((await getApplicationSupportDirectory()).path, "log");
  logger = Logger(
      filter: ProductionFilter(),
      output: MultiOutput([
        AdvancedFileOutput(
          path: logPath, // Path to log folder
        ),
        ConsoleOutput(),
      ]));
  logger.d("Logging at: $logPath");
  final dir = Directory(logPath);
  logger.d(await dir.list().map((e) => e.path).join('\n'));
  // Initialize background fetch
  await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15, // iOS minimum
        stopOnTerminate: false, // Allow Android to survive termination
        enableHeadless: true, // Enable Android headless mode
      ), (taskId) async {
    logger.i("[BackgroundFetch] Event received");
    try {
      // attempt to grab the old location service
      try {
        LocationService locationService = GetIt.I<LocationService>();
        locationService.initializeGroupListeners();
        await locationService.sendLocationUpdateOneShot();
        logger.d("Sucsessfully background oneshot");
      } catch (e) {
        // if it fails create a new one
        logger.e("Failed to get location service: $e");
        logger.d("attempting re-init");
        LocationService locationService =
            await LocationService.initializeForBackground();
        locationService.initializeGroupListeners();
        await locationService.sendLocationUpdateOneShot();
        // Now that it has been re-inited, start listener and update peers
      }

      // await locationService.sendLocationUpdateOneShot();
      logger.i("Background fetch ran");
    } catch (e) {
      logger.e("Background fetch failed: $e");
    }
    // give the listeners some breathing room to finsih and then gracefully exit
    await Future.delayed(const Duration(seconds: 10));
    BackgroundFetch.finish(taskId);
  }, (taskId) => BackgroundFetch.finish(taskId) // Timeout handler
      );
  runApp(
    BlocProvider(
      create: (context) => MainCubit()..initializeApp(),
      child: const Luogo(),
    ),
  );
}

/// Top level Luogo function that defines the material app
class Luogo extends StatelessWidget {
  const Luogo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luogo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light, // Light theme
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // Dark theme
        ),
      ),
      themeMode: ThemeMode.system,
      home: const InitRouterPage(),
    );
  }
}
