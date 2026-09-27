// ProstheticCaseData.isWaitingForPlacement claims to implement the brief's
// automatic-inclusion rule (page 9): "Returned-from-lab date exists AND
// Actual placement date is empty AND status is not Cancelled." Verified
// against the real backend query before writing this test —
// ListProstheticCasesAction::waitingForPlacementQuery() in
// app/Domain/Prosthetic/Actions/ListProstheticCasesAction.php does exactly
// this: whereNotNull('returned_from_lab_date'), whereNull
// ('actual_placement_date'), status != Cancelled. The two sides match
// field for field.
//
// Not covered here (a real, separate gap, not this file's concern): the
// brief also asks for visual aging levels (0-7 / 8-14 / 15+ days,
// page 9). `AgingBadge` already exists in the shared widget kit for
// exactly this purpose but isn't wired into `ProstheticCaseTile`, which
// currently shows the day count in a single fixed color regardless of
// severity — flagged in the task report, not fixed here.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';

ProstheticCaseData _caseWith({
  DateTime? returnedFromLabDate,
  DateTime? actualPlacementDate,
  ProstheticCaseStatus status = ProstheticCaseStatus.receivedAtPractice,
}) =>
    ProstheticCaseData(
      id: 'case-1',
      patientId: 'p1',
      patientReference: 'PAT-000001',
      practitionerId: 'prat-1',
      practitionerName: 'Dr Test',
      status: status,
      impressionType: ProstheticImpressionType.digital,
      workType: ProstheticWorkType.crown,
      impressionDate: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1),
      returnedFromLabDate: returnedFromLabDate,
      actualPlacementDate: actualPlacementDate,
    );

void main() {
  group('ProstheticCaseData.isWaitingForPlacement', () {
    test('false when the case never came back from the laboratory', () {
      final c = _caseWith(returnedFromLabDate: null);
      expect(c.isWaitingForPlacement, isFalse);
    });

    test('true once returned from the lab and not yet placed', () {
      final c = _caseWith(returnedFromLabDate: DateTime(2026, 9, 10));
      expect(c.isWaitingForPlacement, isTrue);
    });

    test('false once the actual placement date is recorded', () {
      final c = _caseWith(
        returnedFromLabDate: DateTime(2026, 9, 10),
        actualPlacementDate: DateTime(2026, 9, 15),
      );
      expect(c.isWaitingForPlacement, isFalse);
    });

    test('false for a cancelled case even if returned and not placed', () {
      final c = _caseWith(
        returnedFromLabDate: DateTime(2026, 9, 10),
        status: ProstheticCaseStatus.cancelled,
      );
      expect(c.isWaitingForPlacement, isFalse);
    });

    test('true regardless of status as long as it is not cancelled', () {
      for (final status in [
        ProstheticCaseStatus.impressionCompleted,
        ProstheticCaseStatus.sentToLaboratory,
        ProstheticCaseStatus.receivedAtPractice,
        ProstheticCaseStatus.placementScheduled,
      ]) {
        final c = _caseWith(
          returnedFromLabDate: DateTime(2026, 9, 10),
          status: status,
        );
        expect(c.isWaitingForPlacement, isTrue, reason: '$status');
      }
    });
  });
}
