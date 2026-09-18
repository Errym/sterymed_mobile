import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_item_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/control_test_data.dart';

CycleData buildCycle({
  String id = 'cycle-1',
  String number = 'CT-001',
  String status = 'created',
}) {
  return CycleData(
    id: id,
    number: number,
    status: status,
    deviceId: 'device-1',
    deviceName: 'Melag Vacuklav',
    createdAt: DateTime(2026, 9, 18, 10, 0),
  );
}

CycleItemData buildCycleItem({String id = 'item-1', String description = 'Test'}) {
  return CycleItemData(
    id: id,
    cycleId: 'cycle-1',
    description: description,
    createdAt: DateTime(2026, 9, 18, 10, 0),
  );
}

ControlTestData buildControlTest({String id = 'test-1'}) {
  return ControlTestData(
    id: id,
    cycleId: 'cycle-1',
    type: ControlTestType.vacuum,
    result: ControlTestResult.pass,
    performedAt: DateTime(2026, 9, 18, 10, 30),
  );
}
