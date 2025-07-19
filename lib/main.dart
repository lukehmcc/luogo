import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/view/page/init_router.dart';
import 'package:workmanager/workmanager.dart';
import 'package:luogo/services/background_service.dart';

// This is my only global var, as no init process
final Logger logger = Logger();

/// Main fucntion that starts everything. Utilizes a Cubit to handle state
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );
  // Register the periodic task
  Workmanager().registerPeriodicTask(
    "Background Location Share-er",
    backgroundLocationTask,
    frequency: Duration(minutes: 15),
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const InitRouterPage(),
    );
  }
}
