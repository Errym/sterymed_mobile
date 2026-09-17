import 'package:equatable/equatable.dart';

class DeviceData extends Equatable {
  final String id;
  final String name;
  final String? model;
  final String? serialNumber;
  final String? status;

  const DeviceData({
    required this.id,
    required this.name,
    this.model,
    this.serialNumber,
    this.status,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) => DeviceData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        model: json['model']?.toString(),
        serialNumber: json['serial_number']?.toString(),
        status: json['status']?.toString(),
      );

  @override
  List<Object?> get props => [id, name];
}
