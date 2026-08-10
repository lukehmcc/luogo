import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/services/background_sync_service.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
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
class Luogo extends StatefulWidget {
  const Luogo({super.key});

  @override
  State<Luogo> createState() => _LuogoState();
}

class _LuogoState extends State<Luogo> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A suspended iOS app misses WebSocket pushes while the socket can still
    // look connected; catch up on anything we missed when we come back.
    try {
      final LocationService locationService = GetIt.I<LocationService>();
      final RelayClient? relay = locationService.relayClient;
      if (relay == null) return;
      if (!relay.isLiveRunning) {
        relay.startLive();
      }
      unawaited(relay.resyncAll());
    } catch (e) {
      logger.e("Resume resync failed: $e");
    }
  }

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
