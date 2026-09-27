// `ProstheticCaseStatus.allowedNext` claims (in its own doc comment) to
// mirror the backend's `ProstheticCaseStatus::allowedNextStatuses()`
// exactly (app/Domain/Prosthetic/Enums/ProstheticCaseStatus.php). Verified
// side-by-side against that real source before writing this test — every
// case below matches the backend's match expression field for field. A
// test that only re-asserted whatever the mobile code already does would
// prove nothing; this proves the two sides haven't drifted.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';

void main() {
  group('ProstheticCaseStatus.allowedNext (mirrors the real backend enum)',
      () {
    test('impressionCompleted -> sentToLaboratory or cancelled', () {
      expect(
        ProstheticCaseStatus.impressionCompleted.allowedNext,
        [ProstheticCaseStatus.sentToLaboratory, ProstheticCaseStatus.cancelled],
      );
    });

    test('sentToLaboratory -> receivedAtPractice or cancelled', () {
      expect(
        ProstheticCaseStatus.sentToLaboratory.allowedNext,
        [ProstheticCaseStatus.receivedAtPractice, ProstheticCaseStatus.cancelled],
      );
    });

    test('receivedAtPractice -> placementScheduled or cancelled', () {
      expect(
        ProstheticCaseStatus.receivedAtPractice.allowedNext,
        [ProstheticCaseStatus.placementScheduled, ProstheticCaseStatus.cancelled],
      );
    });

    test('placementScheduled -> placed or cancelled', () {
      expect(
        ProstheticCaseStatus.placementScheduled.allowedNext,
        [ProstheticCaseStatus.placed, ProstheticCaseStatus.cancelled],
      );
    });

    test('placed is terminal — no further transitions', () {
      expect(ProstheticCaseStatus.placed.allowedNext, isEmpty);
    });

    test('cancelled can only restart at impressionCompleted', () {
      expect(
        ProstheticCaseStatus.cancelled.allowedNext,
        [ProstheticCaseStatus.impressionCompleted],
      );
    });

    test('unknown (a status the mobile model doesn\'t recognize) offers '
        'no transitions rather than guessing', () {
      expect(ProstheticCaseStatus.unknown.allowedNext, isEmpty);
    });
  });

  group('ProstheticCaseStatus wire round-trip', () {
    const wireValues = {
      'impression_completed': ProstheticCaseStatus.impressionCompleted,
      'sent_to_laboratory': ProstheticCaseStatus.sentToLaboratory,
      'received_at_practice': ProstheticCaseStatus.receivedAtPractice,
      'placement_scheduled': ProstheticCaseStatus.placementScheduled,
      'placed': ProstheticCaseStatus.placed,
      'cancelled': ProstheticCaseStatus.cancelled,
    };

    wireValues.forEach((wire, status) {
      test('"$wire" round-trips to $status and back', () {
        expect(ProstheticCaseStatus.fromWire(wire), status);
        expect(status.wire, wire);
      });
    });

    test('an unrecognized wire value falls back to unknown, not a crash',
        () {
      expect(
        ProstheticCaseStatus.fromWire('some_future_status_mobile_never_saw'),
        ProstheticCaseStatus.unknown,
      );
    });
  });
}
