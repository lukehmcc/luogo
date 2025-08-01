import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/init_router.dart';

// This is my only global var, as no init process
final Logger logger = Logger();

/// Main fucntion that starts everything. Utilizes a Cubit to handle state
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize background fetch
  await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15, // iOS minimum
        stopOnTerminate: false, // Allow Android to survive termination
        enableHeadless: true, // Enable Android headless mode
      ), (taskId) async {
    logger.i("[BackgroundFetch] Event received");
    try {
      await GetIt.I<LocationService>().sendLocationUpdateOneShot();
      // await locationService.sendLocationUpdateOneShot();
      logger.i("Background fetch ran");
    } catch (e) {
      logger.e("Background fetch failed: $e");
    }
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
