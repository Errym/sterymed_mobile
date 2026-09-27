import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/key_value_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/local/prosthetic_case_draft_store.dart';

class MockKeyValueStore extends Mock implements KeyValueStore {}

void main() {
  late MockKeyValueStore kv;
  late ProstheticCaseDraftStore drafts;

  const draftKey = 'prosthetic_case_create_draft';

  setUp(() {
    kv = MockKeyValueStore();
    drafts = ProstheticCaseDraftStore(kv);
  });

  group('ProstheticCaseDraft', () {
    test('isEmpty is true with no patient, lab, or text fields', () {
      expect(const ProstheticCaseDraft().isEmpty, isTrue);
    });

    test('isEmpty is false once any field is set', () {
      expect(const ProstheticCaseDraft(patientId: 'p1').isEmpty, isFalse);
      expect(
        const ProstheticCaseDraft(laboratoryId: 'lab1').isEmpty,
        isFalse,
      );
      expect(
        const ProstheticCaseDraft(notes: 'Teinte A2').isEmpty,
        isFalse,
      );
    });
  });

  group('ProstheticCaseDraftStore', () {
    test('load returns null when nothing is stored', () {
      when(() => kv.get(draftKey)).thenReturn(null);
      expect(drafts.load(), isNull);
    });

    test('load returns null for corrupt JSON rather than throwing', () {
      when(() => kv.get(draftKey)).thenReturn('not valid json{{{');
      expect(drafts.load(), isNull);
    });

    test('save then load round-trips every field of the draft', () async {
      final impressionDate = DateTime(2026, 9, 26);
      final draft = ProstheticCaseDraft(
        patientId: 'p1',
        patientReference: 'PAT-000004',
        laboratoryId: 'lab1',
        impressionType: 'physical',
        workType: 'bridge',
        impressionDate: impressionDate,
        priority: 'urgente',
        notes: 'Teinte A2',
        internalComments: 'Patient prévenu',
      );

      String? stored;
      when(() => kv.set(draftKey, any())).thenAnswer((i) async {
        stored = i.positionalArguments[1] as String;
      });

      await drafts.save(draft);

      final decoded = ProstheticCaseDraft.fromJson(
        (jsonDecode(stored!) as Map).cast<String, dynamic>(),
      );
      expect(decoded.patientId, 'p1');
      expect(decoded.patientReference, 'PAT-000004');
      expect(decoded.laboratoryId, 'lab1');
      expect(decoded.impressionType, 'physical');
      expect(decoded.workType, 'bridge');
      expect(decoded.impressionDate, impressionDate);
      expect(decoded.priority, 'urgente');
      expect(decoded.notes, 'Teinte A2');
      expect(decoded.internalComments, 'Patient prévenu');
    });

    test('saving an empty draft clears it instead of writing', () async {
      when(() => kv.delete(draftKey)).thenAnswer((_) async {});

      await drafts.save(const ProstheticCaseDraft());

      verify(() => kv.delete(draftKey)).called(1);
      verifyNever(() => kv.set(any(), any()));
    });

    test('clear deletes the single draft key', () async {
      when(() => kv.delete(draftKey)).thenAnswer((_) async {});
      await drafts.clear();
      verify(() => kv.delete(draftKey)).called(1);
    });
  });
}
