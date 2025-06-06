import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:s5/s5.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:lib5/util.dart';
import 'package:s5_messenger_example/view/demo_main_view.dart';

late S5 s5;
late S5Messenger s5messenger;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Rust
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const InitializationScreen(),
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  bool hiveInitialized = false;
  bool s5Initialized = false;
  bool messengerInitialized = false;
  bool initializationComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeDependencies();
  }

  Future<void> _initializeDependencies() async {
    try {
      // Initialize Hive
      Hive.init('data');
      setState(() => hiveInitialized = true);

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
      setState(() => s5Initialized = true);

      // Initialize S5Messenger
      s5messenger = S5Messenger();
      await s5messenger.init(s5);
      // await s5messenger.init(s5);
      setState(() => messengerInitialized = true);

      // All done
      setState(() => initializationComplete = true);

      // Navigate to home page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MLS5DemoAppView()),
        );
      }
    } catch (e) {
      // Handle initialization errors
      debugPrint('Initialization error: $e');
      // You might want to show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Initializing App...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildInitializationStep('Hive Initialization', hiveInitialized),
            _buildInitializationStep('S5 Initialization', s5Initialized),
            _buildInitializationStep(
              'Messenger Initialization',
              messengerInitialized,
            ),
            if (initializationComplete) ...[
              const SizedBox(height: 32),
              const Text('Ready!', style: TextStyle(fontSize: 20)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitializationStep(String label, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isComplete
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text("App has initialized")));
  }
}

// Quick change of: https://github.com/s5-dev/lib5/blob/main/lib/src/node/logger/simple.dart
// Supresses spammy warns
class SilentLogger extends Logger {
  final String prefix;
  final bool format;
  final bool showVerbose;

  SilentLogger({
    this.prefix = '',
    this.format = true,
    this.showVerbose = false,
  });

  @override
  void info(String s) {
    print(prefix + s.replaceAll(RegExp('\u001b\\[\\d+m'), ''));
  }

  @override
  void error(String s) {
    print('$prefix[ERROR] $s');
  }

  @override
  void verbose(String s) {
    if (!showVerbose) return;
    print(prefix + s);
  }

  @override
  void warn(String s) {
    // Silent - no output
  }

  @override
  void catched(e, st, [context]) {
    // Silent - no output
  }
}
