import 'package:equatable/equatable.dart';

class DeviceDetail extends Equatable {
  final String id;
  final String name;
  final String? model;
  final String? serialNumber;
  final String? status;
  final String? siteId;
  final String? siteName;

  const DeviceDetail({
    required this.id,
    required this.name,
    this.model,
    this.serialNumber,
    this.status,
    this.siteId,
    this.siteName,
  });

  factory DeviceDetail.fromJson(Map<String, dynamic> json) => DeviceDetail(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        model: json['model']?.toString(),
        serialNumber: json['serial_number']?.toString(),
        status: json['status']?.toString(),
        siteId: json['site_id']?.toString(),
        siteName: json['site_name']?.toString(),
      );

  @override
  List<Object?> get props => [id, name, status];
}
