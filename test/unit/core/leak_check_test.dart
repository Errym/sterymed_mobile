// Task 4.3 — dispose/leak audit.
//
// Flutter's built-in `leak_tracker` (`LeakTesting.enable()` in a
// `flutter_test_config.dart`) is NOT available on the Flutter SDK this
// project builds against (`LeakTesting` is not exported by `flutter_test`
// here — confirmed by grepping the actual SDK in use, not just a version
// number) so the brief's preferred approach isn't feasible today. Per the
// brief's own fallback ("if not, document the manual audit"), this test
// is that audit, made deterministic and re-runnable instead of a one-time
// manual pass: it statically scans every file under lib/ for
// `TextEditingController` / `ScrollController` / `PageController` /
// `TabController` / `AnimationController` / `FocusNode` / `StreamController`
// fields and asserts each one a class *owns* (i.e. did not receive as a
// constructor parameter) has a matching `.dispose()`/`.close()` call
// somewhere in that same class.
//
// State at the time this was written (manually verified file-by-file,
// not just by this script): every owned controller in lib/ is disposed.
// The only fields that look "undisposed" are `TextEditingController
// controller` parameters injected by a caller into `AppTextField`,
// `AppTextArea`, `AppSearchField`, and `QuantityStepper` — correctly left
// alone here since the *caller* creates and disposes them, and disposing
// a controller a widget doesn't own would break the caller. Two
// repository/service-level `StreamController`s
// (`ConnectivityService._controller`, `DeviceRepository._changes`) do
// have working `dispose()` methods that close them, even though nothing
// calls `dispose()` on either today (both are GetIt singletons that live
// for the process lifetime with no DI-reset/logout flow that would need
// it) — correct as-is.
//
// If this test ever fails, it means a *new* controller was added without
// a matching dispose — go fix that file, not this test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _controllerTypes = [
  'TextEditingController',
  'ScrollController',
  'PageController',
  'TabController',
  'AnimationController',
  'FocusNode',
];

final _declPattern = RegExp(
  '(?:final|late)\\s+(?:[\\w<>,?\\s]*?)'
  '(${_controllerTypes.join('|')})'
  '(?:<[^>]*>)?\\??\\s+(\\w+)\\s*[=;]',
);

/// Catches the inferred-type declaration style the pattern above misses:
/// `late final _x = TextEditingController(...)` (name before type, type only
/// in the initializer). A real controller leak once hid in exactly this
/// blind spot, so both styles are now scanned.
final _inferredDeclPattern = RegExp(
  '(?:final|late)\\s+(\\w+)\\s*=\\s*(${_controllerTypes.join('|')})\\s*[(<]',
);

final _streamControllerDeclPattern =
    RegExp(r'(?:final|late)\s+(\w+)\s*=\s*StreamController');

final _disposeCallPattern = RegExp(r'(\w+)\s*\.\s*dispose\s*\(\s*\)');
final _closeCallPattern = RegExp(r'(\w+)\s*\.\s*close\s*\(\s*\)');
final _ctorInjectedPattern = RegExp(r'this\.(\w+)');
final _classPattern = RegExp(r'\bclass\s+(\w+)[^{]*\{');

/// Known-correct exceptions: a controller field injected via the
/// constructor, so the *caller* owns disposal, not this class.
const _ctorInjectedAllowlist = <String>{
  'AppTextField.controller',
  'AppTextArea.controller',
  'AppSearchField.controller',
  'QuantityStepper.controller',
};

class _ClassBlock {
  _ClassBlock(this.className, this.body);
  final String className;
  final String body;
}

Iterable<_ClassBlock> _splitClasses(String text) sync* {
  for (final m in _classPattern.allMatches(text)) {
    final start = m.end - 1;
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}') {
        depth--;
        if (depth == 0) {
          yield _ClassBlock(m.group(1)!, text.substring(start, i + 1));
          break;
        }
      }
    }
  }
}

void main() {
  test('every owned controller/focus-node/stream-controller in lib/ is disposed', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'must run `flutter test` from the repo root');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      final relPath = entity.path.replaceAll('\\', '/');

      for (final cls in _splitClasses(text)) {
        final decls = <(String type, String name)>[
          for (final m in _declPattern.allMatches(cls.body))
            (m.group(1)!, m.group(2)!),
          for (final m in _inferredDeclPattern.allMatches(cls.body))
            (m.group(2)!, m.group(1)!),
          for (final m in _streamControllerDeclPattern.allMatches(cls.body))
            ('StreamController', m.group(1)!),
        ];
        if (decls.isEmpty) continue;

        final disposed = <String>{
          for (final m in _disposeCallPattern.allMatches(cls.body)) m.group(1)!,
          for (final m in _closeCallPattern.allMatches(cls.body)) m.group(1)!,
        };
        final ctorInjected = <String>{
          for (final m in _ctorInjectedPattern.allMatches(cls.body)) m.group(1)!,
        };

        for (final (type, name) in decls) {
          if (disposed.contains(name)) continue;
          final key = '${cls.className}.$name';
          if (ctorInjected.contains(name) && _ctorInjectedAllowlist.contains(key)) {
            continue;
          }
          violations.add(
            '$relPath :: class ${cls.className} :: $type $name'
            '${ctorInjected.contains(name) ? ' (ctor-injected, NOT on the allowlist — add it to _ctorInjectedAllowlist only if the caller truly owns disposal)' : ' has no matching .dispose()/.close() call'}',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
