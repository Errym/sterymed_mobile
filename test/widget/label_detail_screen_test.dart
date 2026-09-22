import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_data.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/screens/label_detail_screen.dart';

import '../helpers/pump_app.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

class MockLabelUsageRepository extends Mock implements LabelUsageRepository {}

const _label = LabelData(
  id: 'label-1',
  code: 'LOT-42',
  status: 'valid',
  productName: 'Gants nitrile',
  batchNumber: 'B-42',
);

void main() {
  late MockLabelRepository repo;
  late MockLabelUsageRepository usageRepo;

  setUp(() {
    repo = MockLabelRepository();
    usageRepo = MockLabelUsageRepository();
    when(() => usageRepo.history(any())).thenAnswer((_) async => []);
  });

  Widget wrap(Widget child) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LabelRepository>.value(value: repo),
          RepositoryProvider<LabelUsageRepository>.value(value: usageRepo),
        ],
        child: child,
      );

  testWidgets('renders product info for a valid label', (tester) async {
    when(() => repo.getByCode(any())).thenAnswer((_) async => const LabelScanResult(
          code: 'LOT-42',
          status: LabelScanStatus.valid,
          label: _label,
        ));

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'LOT-42')));
    await tester.pumpAndSettle();

    expect(find.text('Gants nitrile'), findsOneWidget);
  });

  testWidgets('shows error view when the lookup fails', (tester) async {
    when(() => repo.getByCode(any())).thenThrow(
      const ApiException(code: 'not_found', message: 'Étiquette introuvable.'),
    );

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'UNKNOWN')));
    await tester.pumpAndSettle();

    expect(find.text('Étiquette introuvable.'), findsOneWidget);
  });

  testWidgets('shows loading state before the result arrives', (tester) async {
    // Never-completing future rather than Future.delayed — a real Timer
    // left pending past the test body trips flutter_test's
    // '!timersPending' invariant. We only need the request to still be
    // in flight when we assert, not to actually resolve.
    final neverCompletes = Completer<LabelScanResult>();
    when(() => repo.getByCode(any()))
        .thenAnswer((_) => neverCompletes.future);

    await pumpApp(tester, wrap(const LabelDetailScreen(code: 'LOT-42')));
    await tester.pump();

    expect(find.text('Chargement de l\'étiquette...'), findsOneWidget);
  });
}
