import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/utils/s5_logger.dart';
import 'package:luogo/view/page/home.dart';
import 'package:path_provider/path_provider.dart';
import 'package:s5/s5.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

// Some global variables for easy of use
late S5 s5;
late S5Messenger s5messenger;
late SharedPreferences prefs;
late Logger logger;
late LocationService locationService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance(); // Quick so init here
  await RustLib.init(); // Init the rust bindings
  logger = Logger(); // Define the logger
  // Start the location service loop
  await _initHive();
  locationService = LocationService();
  locationService.startPeriodicUpdates(intervalMinutes: 5);
  // _initializeDependencies();
  runApp(const Luogo());
}

Future<void> _initHive() async {
  final dir =
      await getApplicationDocumentsDirectory(); // Best for persistent data
  Hive.init(path.join(dir.path, 'hive'));
}

// Initializes all the slow dependecies async
Future<void> _initializeDependencies() async {
  try {
    // Initialize Hive

    // Initialize S5
    s5 = await S5.create(
      initialPeers: [
        'wss://z2DeVYsXdq3Rgt8252LRwNnreAtsGr3BN6FPc6Hvg6dTtRk@s5.jptr.tech/s5/p2p', // add my S5 node first
        'wss://z2Das8aEF7oNoxkcrfvzerZ1iBPWfm6D7gy3hVE4ALGSpVB@node.sfive.net/s5/p2p',
        'wss://z2DdbxV4xyoqWck5pXXJdVzRnwQC6Gbv6o7xDvyZvzKUfuj@s5.vup.dev/s5/p2p',
        'wss://z2DWuWNZcdSyZLpXFK2uCU3haaWMXrDAgxzv17sDEMHstZb@s5.garden/s5/p2p',
      ],
      logger: SilentLogger(),
    );

    // Initialize S5Messenger
    s5messenger = S5Messenger();
    // await s5messenger.init(s5);
  } catch (e) {
    // Handle initialization errors
    debugPrint('Initialization error: $e');
    // You might want to show an error message to the user
  }
}

class Luogo extends StatelessWidget {
  const Luogo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luogo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}
