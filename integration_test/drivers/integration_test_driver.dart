// Host-side driver for `flutter drive` (needed for -d chrome, where
// `flutter test` doesn't support integration_test on web devices).
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
