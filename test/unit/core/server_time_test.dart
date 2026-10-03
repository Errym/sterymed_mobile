// A clinical record must show the time it happened on the person's own clock.
// The API sends UTC; reading it as-is showed every cycle, usage and audit time
// one or two hours early in France.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/server_time.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/history/data/models/audit_event_data.dart';

void main() {
  group('parseServerTime', () {
    test('a UTC timestamp becomes the phone\'s local time, same instant', () {
      final parsed = parseServerTime('2026-10-03T07:15:40+00:00')!;
      expect(parsed.isUtc, isFalse);
      expect(parsed.toUtc(), DateTime.utc(2026, 10, 3, 7, 15, 40));
    });

    test('shown on a clock, it matches the local hour (not the UTC one)', () {
      final utc = DateTime.utc(2026, 10, 3, 7, 15, 40);
      final parsed = parseServerTime('2026-10-03T07:15:40Z')!;
      // Whatever zone the machine runs in, the displayed hour is the local one.
      expect(parsed.hour, utc.toLocal().hour);
    });

    test('a date-only value stays the same calendar day', () {
      final parsed = parseServerTime('2026-11-03')!;
      expect([parsed.year, parsed.month, parsed.day], [2026, 11, 3]);
    });

    test('missing, empty or garbage is null, never "now" or the epoch', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('   '), isNull);
      expect(parseServerTime('not a date'), isNull);
    });
  });

  group('models read server times as local', () {
    test('a cycle\'s start and end', () {
      final c = CycleData.fromJson(const {
        'id': 'c1',
        'cycle_number': 12,
        'status': 'in_progress',
        'device': {'id': 'd1', 'name': 'Autoclave'},
        'created_at': '2026-10-03T06:00:00+00:00',
        'started_at': '2026-10-03T07:00:00+00:00',
        'completed_at': '2026-10-03T08:12:00+00:00',
      });
      expect(c.startedAt!.isUtc, isFalse);
      expect(c.completedAt!.isUtc, isFalse);
      expect(
        c.completedAt!.difference(c.startedAt!),
        const Duration(hours: 1, minutes: 12),
        reason: 'converting must not change the duration',
      );
    });

    test('an audit event\'s time', () {
      final e = AuditEventData.fromJson(const {
        'id': 'a1',
        'action': 'cycle.created',
        'occurred_at': '2026-10-03T07:15:40+00:00',
      });
      expect(e.occurredAt.isUtc, isFalse);
      expect(e.occurredAt.toUtc(), DateTime.utc(2026, 10, 3, 7, 15, 40));
    });
  });

  group('honesty: a missing date stays missing', () {
    test('a cycle the server sends without created_at has no creation time', () {
      // This is what the real API returns for cycles (verified on the live
      // server): no created_at. The app used to show the CURRENT time as the
      // creation time, which changed on every refresh.
      final c = CycleData.fromJson(const {
        'id': 'c1',
        'cycle_number': 12,
        'status': 'created',
        'device': {'id': 'd1', 'name': 'Autoclave'},
        'started_at': null,
        'completed_at': null,
      });
      expect(c.createdAt, isNull);
      expect(c.startedAt, isNull);
    });
  });
}
