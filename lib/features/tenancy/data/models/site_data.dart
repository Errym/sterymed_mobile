import 'package:equatable/equatable.dart';

class SiteData extends Equatable {
  final String id;
  final String name;
  final String? kind;
  final String? address;
  final int roomCount;
  final int deviceCount;
  final int armoryCount;

  const SiteData({
    required this.id,
    required this.name,
    this.kind,
    this.address,
    this.roomCount = 0,
    this.deviceCount = 0,
    this.armoryCount = 0,
  });

  factory SiteData.fromJson(Map<String, dynamic> json) => SiteData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        kind: json['kind']?.toString(),
        address: json['address']?.toString(),
        roomCount: (json['room_count'] as num?)?.toInt() ?? 0,
        deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
        armoryCount: (json['armory_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, name, kind];
}
