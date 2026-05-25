import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/services/background_sync_service.dart';
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

  // Configure background sync
  await BackgroundSyncService.configure();

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
