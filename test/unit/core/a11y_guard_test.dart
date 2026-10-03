// Every icon-only button needs a spoken label (tooltip): without it a screen
// reader says just "button". Scans the source so a new unlabeled one fails CI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every IconButton in lib/ has a tooltip', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = file.readAsStringSync();
      for (final m in RegExp(r'IconButton\(').allMatches(text)) {
        // Take the balanced argument list of this constructor call.
        var depth = 1;
        var i = m.end;
        while (i < text.length && depth > 0) {
          if (text[i] == '(') depth++;
          if (text[i] == ')') depth--;
          i++;
        }
        final call = text.substring(m.start, i);
        if (!call.contains('tooltip:')) {
          final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'IconButton without tooltip');
  });
}
