// Structural rules that keep the code base maintainable. They fail the build
// the moment a rule is broken, so quality cannot drift back unnoticed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String norm(String p) => p.split(r'\').join('/');

void main() {
  test('no source file is longer than 800 lines (split it into parts or widgets)', () {
    final tooLong = <String>[];
    for (final f in dartFiles('lib')) {
      final lines = f.readAsLinesSync().length;
      if (lines > 800) tooLong.add('${norm(f.path)} ($lines lines)');
    }
    expect(tooLong, isEmpty);
  });

  test('screens and cubits never reach into a data source: they go through a repository', () {
    final offenders = <String>[];
    for (final f in dartFiles('lib/features')) {
      final path = norm(f.path);
      if (!path.contains('/presentation/')) continue;
      if (f.readAsStringSync().contains(RegExp(r"import '[^']*/datasources/"))) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the data layer never imports from presentation', () {
    final offenders = <String>[];
    for (final f in dartFiles('lib/features')) {
      final path = norm(f.path);
      if (!path.contains('/data/')) continue;
      if (f.readAsStringSync().contains(RegExp(r"import '[^']*/presentation/"))) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('service-locator calls inside screens may only go down (ceiling 200)', () {
    // Screens that look up their dependencies with getIt<> are harder to test
    // and to reuse than ones that receive a bloc or a repository. The count is
    // a ceiling, lowered whenever a screen is cleaned up, never raised.
    var count = 0;
    for (final f in dartFiles('lib/features')) {
      if (!norm(f.path).contains('/presentation/')) continue;
      count += 'getIt<'.allMatches(f.readAsStringSync()).length;
    }
    expect(count, lessThanOrEqualTo(200), reason: 'found $count');
  });
}
