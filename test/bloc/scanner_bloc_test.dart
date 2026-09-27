import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/scanner/presentation/bloc/scanner_bloc.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

LabelScanResult _validResult({String labelId = 'l1', int cycleNumber = 1}) {
  return LabelScanResult(
    labelId: labelId,
    status: LabelScanStatus.used,
    cycleNumber: cycleNumber,
    deviceName: 'Autoclave 1',
    sterilizedAt: DateTime(2026, 1, 1),
    useByDate: DateTime(2026, 6, 1),
    sequenceInCycle: 1,
    siteName: 'Cabinet Principal',
  );
}

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
        when(() => repo.getByCode(any()))
            .thenAnswer((_) async => _validResult(labelId: 'l1'));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-1')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved)
            .having((s) => s.result?.labelId, 'result.labelId', 'l1'),
        // the cooldown timer fires within `wait` and transitions back
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'an expired label never resolves — the real backend throws before '
      'returning a status, so this is an error with errorCode set',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenThrow(const ApiException(
          code: 'LABEL_EXPIRED',
          message: 'This label is past its use-by date.',
          statusCode: 410,
        ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-2')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.error)
            .having((s) => s.errorCode, 'errorCode', 'LABEL_EXPIRED'),
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
        when(() => repo.getByCode(any()))
            .thenAnswer((_) async => _validResult(labelId: 'l1'));
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
