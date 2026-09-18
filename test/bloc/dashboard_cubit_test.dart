import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/dashboard/data/models/dashboard_data.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_state.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}
class MockSessionStore extends Mock implements SessionStore {}

const _emptyDashboard = DashboardData(
  greeting: 'Bonjour',
  userName: '',
  kpis: [],
  attention: [],
  todayCycles: [],
  recentProcedures: [],
);

void main() {
  late MockDashboardRepository repo;
  late MockSessionStore session;

  setUp(() {
    repo = MockDashboardRepository();
    session = MockSessionStore();
    when(() => session.userName).thenReturn('Dr Test');
  });

  group('DashboardCubit', () {
    blocTest<DashboardCubit, DashboardState>(
      'loads successfully',
      build: () => DashboardCubit(repo, session),
      setUp: () {
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => _emptyDashboard);
      },
      act: (c) => c.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>(),
      ],
    );

    blocTest<DashboardCubit, DashboardState>(
      'emits error on failure',
      build: () => DashboardCubit(repo, session),
      setUp: () {
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenThrow(Exception('boom'));
      },
      act: (c) => c.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardError>(),
      ],
    );
  });
}
