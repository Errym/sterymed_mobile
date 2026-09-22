import 'package:steriymed_mobile/features/history/data/models/audit_event_data.dart';

AuditEventData buildAuditEvent({
  String id = 'event-1',
  String action = 'auth.login_succeeded',
}) {
  return AuditEventData(
    id: id,
    actorId: 'user-1',
    actorLabel: 'Dr Test <test@test.com>',
    action: action,
    subjectType: 'App\\Models\\User',
    subjectId: 'user-1',
    occurredAt: DateTime(2026, 9, 18, 10, 0),
  );
}
