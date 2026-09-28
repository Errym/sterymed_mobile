import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:steriymed_mobile/core/config/build_info.dart';

void main() {
  group('BuildInfo', () {
    test('fullVersion combines version and buildNumber', () {
      expect(BuildInfo.fullVersion,
          '${BuildInfo.version} (${BuildInfo.buildNumber})');
    });

    test(
      'initialize() adopts the platform-reported version/buildNumber, '
      'so a pubspec.yaml bump needs no edit here once wired up at startup',
      () async {
        PackageInfo.setMockInitialValues(
          appName: 'SteryMed',
          packageName: 'com.sterymed.mobile',
          version: '9.9.9',
          buildNumber: '42',
          buildSignature: '',
        );

        await BuildInfo.initialize();

        expect(BuildInfo.version, '9.9.9');
        expect(BuildInfo.buildNumber, '42');
        expect(BuildInfo.fullVersion, '9.9.9 (42)');
      },
    );
  });
}
