import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_data.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/scanner/presentation/bloc/scanner_bloc.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

void main() {
  late MockLabelRepository repo;

  setUp(() {
    repo = MockLabelRepository();
  });

  group('ScannerBloc', () {
    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, resolved] on valid scan',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenAnswer((_) async =>
            const LabelScanResult(
              code: 'LABEL-1',
              status: LabelScanStatus.valid,
              label: LabelData(id: 'l1', code: 'LABEL-1', status: 'valid'),
            ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-1')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved),
        // the cooldown timer fires within `wait` and transitions back
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, resolved] with blocked status for expired label',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenAnswer((_) async =>
            const LabelScanResult(
              code: 'LABEL-2',
              status: LabelScanStatus.expired,
              reason: 'Expiré',
            ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-2')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved)
            .having((s) => s.result?.status, 'result.status',
                LabelScanStatus.expired),
        // the cooldown timer fires within `wait` and transitions back
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, error] on network error',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any()))
            .thenThrow(const ApiException(
          code: 'network_error',
          message: 'Connexion impossible.',
        ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-3')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.error),
        // the cooldown timer fires within `wait` and transitions back
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'unknown code emits error',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenThrow(const ApiException(
          code: 'not_found',
          message: 'Étiquette introuvable.',
        ));
      },
      act: (bloc) => bloc.add(const ScanDetected('UNKNOWN-CODE')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.error)
            .having((s) => s.error, 'error', 'Étiquette introuvable.'),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'a second scan during the cooldown window is ignored — no double-fire',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenAnswer((_) async =>
            const LabelScanResult(
              code: 'LABEL-1',
              status: LabelScanStatus.valid,
              label: LabelData(id: 'l1', code: 'LABEL-1', status: 'valid'),
            ));
      },
      act: (bloc) async {
        bloc.add(const ScanDetected('LABEL-1'));
        // Still resolving/resolved at this point — well inside the
        // 400ms cooldown — so this second scan must be dropped.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ScanDetected('LABEL-1'));
      },
      wait: const Duration(milliseconds: 500),
      verify: (_) {
        verify(() => repo.getByCode(any())).called(1);
      },
    );

    test('torch toggles', () async {
      final bloc = ScannerBloc(repo);
      expect(bloc.state.torchOn, false);
      bloc.add(const TorchToggled());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.torchOn, true);
      bloc.add(const TorchToggled());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.torchOn, false);
      await bloc.close();
    });

    test('reset returns to initial state', () {
      final bloc = ScannerBloc(repo);
      bloc.add(const ScannerReset());
      expect(bloc.state.status, ScannerStatus.initial);
      bloc.close();
    });
  });
}
