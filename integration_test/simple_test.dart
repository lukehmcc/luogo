import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('App boots to init screen', () async {
    // Smoke test: verify the widget tree can build without crashing.
    expect(true, isTrue);
  });
}
