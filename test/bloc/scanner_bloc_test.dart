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
    test('valid scan resolves and produces a result', () async {
      when(() => repo.getByCode(any())).thenAnswer((_) async =>
          const LabelScanResult(
            code: 'LABEL-1',
            status: LabelScanStatus.valid,
            label: LabelData(id: 'l1', code: 'LABEL-1', status: 'valid'),
          ));

      final bloc = ScannerBloc(repo);
      bloc.add(const ScanDetected('LABEL-1'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.status, ScannerStatus.resolved);
      expect(bloc.state.result?.status, LabelScanStatus.valid);
      await bloc.close();
    });

    test('blocked label resolves with blocked status', () async {
      when(() => repo.getByCode(any())).thenAnswer((_) async =>
          const LabelScanResult(
            code: 'LABEL-2',
            status: LabelScanStatus.expired,
            reason: 'Expiré',
          ));

      final bloc = ScannerBloc(repo);
      bloc.add(const ScanDetected('LABEL-2'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.status, ScannerStatus.resolved);
      expect(bloc.state.result?.status, LabelScanStatus.expired);
      expect(bloc.state.result?.isBlocked, isTrue);
      await bloc.close();
    });

    test('network error produces error state', () async {
      when(() => repo.getByCode(any()))
          .thenThrow(const ApiException(
        code: 'network_error',
        message: 'Connexion impossible.',
      ));

      final bloc = ScannerBloc(repo);
      bloc.add(const ScanDetected('LABEL-3'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.status, ScannerStatus.error);
      expect(bloc.state.error, isNotNull);
      await bloc.close();
    });

    test('torch toggles', () async {
      final bloc = ScannerBloc(repo);
      expect(bloc.state.torchOn, false);
      bloc.add(const TorchToggled());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.torchOn, true);
      bloc.add(const TorchToggled());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.torchOn, false);
      await bloc.close();
    });

    test('reset returns to initial state', () async {
      final bloc = ScannerBloc(repo);
      bloc.add(const ScannerReset());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.status, ScannerStatus.initial);
      await bloc.close();
    });
  });
}
