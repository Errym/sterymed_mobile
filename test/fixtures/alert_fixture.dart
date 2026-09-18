import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';

AlertData buildAlert({
  String id = 'alert-1',
  AlertSeverity severity = AlertSeverity.critical,
  String type = 'low_stock',
}) {
  return AlertData(
    id: id,
    type: type,
    severity: severity,
    message: 'Stock faible pour Gants nitrile',
    createdAt: DateTime(2026, 9, 18, 10, 0),
    resolved: false,
  );
}
