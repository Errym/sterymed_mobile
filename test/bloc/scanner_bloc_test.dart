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
      'emits [resolving, resolved, scanning] on valid scan',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any()))
            .thenAnswer((_) async => const LabelScanResult(
                  code: 'LABEL-1',
                  status: LabelScanStatus.valid,
                  label: LabelData(id: 'l1', code: 'LABEL-1', status: 'valid'),
                ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-1')),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, resolved, scanning] with blocked status for expired label',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any()))
            .thenAnswer((_) async => const LabelScanResult(
                  code: 'LABEL-2',
                  status: LabelScanStatus.expired,
                  reason: 'Expiré',
                ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-2')),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved)
            .having((s) => s.result?.status, 'result.status',
                LabelScanStatus.expired),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, error, scanning] on network error',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenThrow(const ApiException(
          code: 'network_error',
          message: 'Connexion impossible.',
        ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-3')),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.error),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.scanning),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'torch toggles',
      build: () => ScannerBloc(repo),
      act: (bloc) => bloc.add(const TorchToggled()),
      expect: () => [
        isA<ScannerState>().having((s) => s.torchOn, 'torchOn', true),
      ],
    );

    test('reset returns to initial state', () {
      final bloc = ScannerBloc(repo);
      bloc.add(const ScannerReset());
      expect(bloc.state.status, ScannerStatus.initial);
      bloc.close();
    });
  });
}
