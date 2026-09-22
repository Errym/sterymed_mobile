import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/key_value_store.dart';
import 'package:steriymed_mobile/features/labels/data/local/label_usage_draft_store.dart';

class MockKeyValueStore extends Mock implements KeyValueStore {}

void main() {
  late MockKeyValueStore kv;
  late LabelUsageDraftStore drafts;

  setUp(() {
    kv = MockKeyValueStore();
    drafts = LabelUsageDraftStore(kv);
  });

  group('LabelUsageDraft', () {
    test('isEmpty is true with no patient, procedure, or notes', () {
      expect(const LabelUsageDraft().isEmpty, isTrue);
    });

    test('isEmpty is false once any field is set', () {
      expect(const LabelUsageDraft(procedure: 'Détartrage').isEmpty, isFalse);
      expect(const LabelUsageDraft(patientId: 'p1').isEmpty, isFalse);
    });

    test('patient reconstructs a minimal PatientData when patientId is set',
        () {
      const draft = LabelUsageDraft(
        patientId: 'p1',
        patientFirstName: 'Marie',
        patientLastName: 'Curie',
      );
      expect(draft.patient?.id, 'p1');
      expect(draft.patient?.fullName, 'Marie Curie');
    });

    test('patient is null when patientId is null', () {
      expect(const LabelUsageDraft().patient, isNull);
    });
  });

  group('LabelUsageDraftStore', () {
    test('load returns null when nothing is stored', () {
      when(() => kv.get('label_usage_draft:label-1')).thenReturn(null);
      expect(drafts.load('label-1'), isNull);
    });

    test('load returns null for corrupt JSON rather than throwing', () {
      when(() => kv.get('label_usage_draft:label-1'))
          .thenReturn('not valid json{{{');
      expect(drafts.load('label-1'), isNull);
    });

    test('save then load round-trips the draft', () {
      const draft = LabelUsageDraft(
        patientId: 'p1',
        patientFirstName: 'Marie',
        patientLastName: 'Curie',
        procedure: 'Détartrage',
        notes: 'RAS',
      );
      String? stored;
      when(() => kv.set('label_usage_draft:label-1', any())).thenAnswer(
        (i) async {
          stored = i.positionalArguments[1] as String;
        },
      );

      drafts.save('label-1', draft);

      final decoded =
          LabelUsageDraft.fromJson(jsonDecode(stored!) as Map<String, dynamic>);
      expect(decoded.patientId, 'p1');
      expect(decoded.procedure, 'Détartrage');
      expect(decoded.notes, 'RAS');
    });

    test('saving an empty draft clears it instead of writing', () async {
      when(() => kv.delete('label_usage_draft:label-1'))
          .thenAnswer((_) async {});

      await drafts.save('label-1', const LabelUsageDraft());

      verify(() => kv.delete('label_usage_draft:label-1')).called(1);
      verifyNever(() => kv.set(any(), any()));
    });

    test('clear deletes the key for that label', () async {
      when(() => kv.delete('label_usage_draft:label-1'))
          .thenAnswer((_) async {});
      await drafts.clear('label-1');
      verify(() => kv.delete('label_usage_draft:label-1')).called(1);
    });

    test('drafts for different labels use different keys', () {
      when(() => kv.get(any())).thenReturn(null);
      drafts.load('label-1');
      drafts.load('label-2');
      verify(() => kv.get('label_usage_draft:label-1')).called(1);
      verify(() => kv.get('label_usage_draft:label-2')).called(1);
    });
  });
}
