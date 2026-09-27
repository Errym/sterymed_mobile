// Tests ProstheticCaseData.hasPaymentDue — the one real, existing piece of
// payment logic on the mobile model. Note: the brief (page 8) says
// "Remaining balance should be automatically recalculated when amounts
// change" — neither this model nor UpdateProstheticCaseRequest on the
// backend actually do that calculation (remaining_balance is a plain
// directly-set numeric field on both sides, not derived). That's a real
// gap in the payment screen itself (Task 1.4/1.5 territory), not
// something to test around here — flagging in the report rather than
// writing a test for behavior that doesn't exist.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';

ProstheticCaseData _caseWith({
  bool depositRequested = false,
  bool depositReceived = false,
  double? remainingBalance,
}) =>
    ProstheticCaseData(
      id: 'case-1',
      patientId: 'p1',
      patientReference: 'PAT-000001',
      practitionerId: 'prat-1',
      practitionerName: 'Dr Test',
      status: ProstheticCaseStatus.receivedAtPractice,
      impressionType: ProstheticImpressionType.digital,
      workType: ProstheticWorkType.crown,
      impressionDate: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1),
      depositRequested: depositRequested,
      depositReceived: depositReceived,
      remainingBalance: remainingBalance,
    );

void main() {
  group('ProstheticCaseData.hasPaymentDue', () {
    test('false when no deposit was requested and no balance remains', () {
      final c = _caseWith();
      expect(c.hasPaymentDue, isFalse);
    });

    test('true when a deposit was requested but not received', () {
      final c = _caseWith(depositRequested: true, depositReceived: false);
      expect(c.hasPaymentDue, isTrue);
    });

    test('false once the requested deposit is received (and no balance)',
        () {
      final c = _caseWith(depositRequested: true, depositReceived: true);
      expect(c.hasPaymentDue, isFalse);
    });

    test('true when a positive balance remains, regardless of deposit state',
        () {
      final c = _caseWith(
        depositRequested: true,
        depositReceived: true,
        remainingBalance: 125.0,
      );
      expect(c.hasPaymentDue, isTrue);
    });

    test('false when the remaining balance is exactly zero', () {
      final c = _caseWith(
        depositRequested: true,
        depositReceived: true,
        remainingBalance: 0,
      );
      expect(c.hasPaymentDue, isFalse);
    });

    test('a null remaining balance never triggers payment-due on its own',
        () {
      final c = _caseWith(remainingBalance: null);
      expect(c.hasPaymentDue, isFalse);
    });
  });
}
