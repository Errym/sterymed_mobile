import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockCycleRepository extends Mock implements CycleRepository {}
class MockLabelRepository extends Mock implements LabelRepository {}
class MockStockRepository extends Mock implements StockRepository {}
class MockDashboardRepository extends Mock implements DashboardRepository {}
class MockAlertRepository extends Mock implements AlertRepository {}
