import 'package:lib5/util.dart';

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
