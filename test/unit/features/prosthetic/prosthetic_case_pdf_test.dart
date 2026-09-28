import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/utils/prosthetic_case_pdf.dart';

import '../../../fixtures/prosthetic_case_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildProstheticCasePdf', () {
    test('produces a non-empty, valid PDF document for a minimal case',
        () async {
      final bytes = await buildProstheticCasePdf(buildProstheticCase());

      expect(bytes, isNotEmpty);
      // The PDF magic header — proves this is a real PDF, not empty/garbage
      // bytes, without needing a full PDF parser.
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });

    test(
      'does not throw when every optional field (lab, dates, notes, '
      'payment amounts) is present',
      () async {
        final c = buildProstheticCase(
          laboratoryName: 'Labo Test',
          sentToLabDate: DateTime(2026, 9, 2),
          returnedFromLabDate: DateTime(2026, 9, 10),
          plannedPlacementDate: DateTime(2026, 9, 15),
          actualPlacementDate: DateTime(2026, 9, 16),
          notes: 'Couronne céramo-métallique sur 26.',
          depositAmount: 100,
          remainingBalance: 42.5,
        );

        final bytes = await buildProstheticCasePdf(c);

        expect(bytes, isNotEmpty);
      },
    );
  });
}
