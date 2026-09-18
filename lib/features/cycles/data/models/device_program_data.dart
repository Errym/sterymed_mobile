import 'package:equatable/equatable.dart';

class DeviceProgramData extends Equatable {
  final String id;
  final String deviceId;
  final String name;
  final int temperatureCelsius;
  final int plateauMinutes;
  final bool isActive;

  const DeviceProgramData({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.temperatureCelsius,
    required this.plateauMinutes,
    required this.isActive,
  });

  factory DeviceProgramData.fromJson(Map<String, dynamic> json) {
    return DeviceProgramData(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      temperatureCelsius:
          (json['target_temperature_celsius'] as num?)?.toInt() ?? 0,
      plateauMinutes: (json['plateau_minutes'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// "Bowie-Dick test · 134 °C · 3 min"
  String get displayLabel =>
      '$name · $temperatureCelsius °C · $plateauMinutes min';

  @override
  List<Object?> get props => [id, deviceId, name, isActive];
}
