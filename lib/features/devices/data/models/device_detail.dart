import 'package:equatable/equatable.dart';

class DeviceDetail extends Equatable {
  final String id;
  final String name;
  final String? model;
  final String? serialNumber;
  final String? manufacturer;
  final String? status;

  /// `autoclave`, `washer_disinfector`, `sealer` or `other`.
  final String? kind;
  final String? siteId;
  final String? siteName;
  final String? notes;
  final DateTime? commissionedAt;
  final DateTime? decommissionedAt;

  const DeviceDetail({
    required this.id,
    required this.name,
    this.model,
    this.serialNumber,
    this.manufacturer,
    this.status,
    this.kind,
    this.siteId,
    this.siteName,
    this.notes,
    this.commissionedAt,
    this.decommissionedAt,
  });

  factory DeviceDetail.fromJson(Map<String, dynamic> json) => DeviceDetail(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        model: json['model']?.toString(),
        serialNumber: json['serial_number']?.toString(),
        manufacturer: json['manufacturer']?.toString(),
        status: json['status']?.toString(),
        kind: json['kind']?.toString(),
        siteId: json['site_id']?.toString(),
        siteName: json['site_name']?.toString(),
        notes: json['notes']?.toString(),
        commissionedAt:
            DateTime.tryParse(json['commissioned_at']?.toString() ?? ''),
        decommissionedAt:
            DateTime.tryParse(json['decommissioned_at']?.toString() ?? ''),
      );

  /// The same device with the site's name filled in (the API sends only the
  /// site's id).
  DeviceDetail withSiteName(String? name) => DeviceDetail(
        id: id,
        name: this.name,
        model: model,
        serialNumber: serialNumber,
        manufacturer: manufacturer,
        status: status,
        kind: kind,
        siteId: siteId,
        siteName: name ?? siteName,
        notes: notes,
        commissionedAt: commissionedAt,
        decommissionedAt: decommissionedAt,
      );

  String get kindLabel => switch (kind) {
        'autoclave' => 'Autoclave',
        'washer_disinfector' => 'Laveur désinfecteur',
        'sealer' => 'Thermoscelleuse',
        'other' => 'Autre appareil',
        _ => 'Appareil',
      };

  String get statusLabel => switch (status) {
        'active' => 'Actif',
        'maintenance' => 'En maintenance',
        'decommissioned' => 'Hors service',
        _ => status ?? '—',
      };

  bool get isActive => status == 'active';

  /// "Autoclave · Melag Vacuklav 40B+" for the line under the name.
  String? get makeAndModel {
    final parts = [manufacturer, model]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  List<Object?> get props => [id, name, status, kind];
}
