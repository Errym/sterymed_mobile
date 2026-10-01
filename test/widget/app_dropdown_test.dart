// The shared dropdown backs most forms and filter sheets, so its two sharp
// edges are pinned down here: it must follow the parent's value (async
// defaults, "clear filters"), and a saved value that is no longer among the
// options must stay visible instead of asserting or silently changing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/shared/widgets/inputs/app_dropdown.dart';

import '../helpers/pump_app.dart';

class _Harness extends StatefulWidget {
  final String? initial;
  final List<AppDropdownOption<String?>> options;
  const _Harness({required this.initial, required this.options});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String? value = widget.initial;
  String? lastChange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppDropdown<String?>(
            label: 'Famille',
            value: value,
            options: widget.options,
            onChanged: (v) => setState(() {
              value = v;
              lastChange = v;
            }),
          ),
          TextButton(
            onPressed: () => setState(() => value = null),
            child: const Text('effacer'),
          ),
          TextButton(
            onPressed: () => setState(() => value = 'b'),
            child: const Text('choisir B'),
          ),
        ],
      ),
    );
  }
}

const _options = [
  AppDropdownOption<String?>(value: null, label: 'Aucune'),
  AppDropdownOption<String?>(value: 'a', label: 'Alpha'),
  AppDropdownOption<String?>(value: 'b', label: 'Bravo'),
];

void main() {
  testWidgets('shows the initial value', (tester) async {
    await pumpApp(tester, const _Harness(initial: 'a', options: _options));
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('follows the parent when it clears the value ("clear filters")', (
    tester,
  ) async {
    await pumpApp(tester, const _Harness(initial: 'a', options: _options));
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('effacer'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Aucune'), findsOneWidget);
  });

  testWidgets('follows the parent when it sets a value later (async default)', (
    tester,
  ) async {
    await pumpApp(tester, const _Harness(initial: null, options: _options));

    await tester.tap(find.text('choisir B'));
    await tester.pumpAndSettle();

    expect(find.text('Bravo'), findsOneWidget);
  });

  testWidgets('selecting an option reports it', (tester) async {
    await pumpApp(tester, const _Harness(initial: null, options: _options));

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha').last);
    await tester.pumpAndSettle();

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    expect(state.lastChange, 'a');
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets(
    'a saved value missing from the options stays visible and does not crash',
    (tester) async {
      await pumpApp(
        tester,
        const _Harness(initial: 'archived-id', options: _options),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(AppDropdown.unavailableLabel), findsOneWidget);
    },
  );

  testWidgets('with no options loaded yet, a saved value does not crash', (
    tester,
  ) async {
    await pumpApp(tester, const _Harness(initial: 'a', options: []));

    expect(tester.takeException(), isNull);
    expect(find.text(AppDropdown.unavailableLabel), findsOneWidget);
  });
}
