import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:s5/s5.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:lib5/util.dart';
import 'package:luogo/view/page/map.dart';

late S5 s5;
late S5Messenger s5messenger;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Rust
  await RustLib.init();
  runApp(const Luogo());
}

Future<void> _initializeDependencies() async {
  try {
    // Initialize Hive
    final dir =
        await getApplicationDocumentsDirectory(); // Best for persistent data
    Hive.init(dir.path);

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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapView(),
    );
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
