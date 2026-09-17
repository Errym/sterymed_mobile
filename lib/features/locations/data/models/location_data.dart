import 'package:equatable/equatable.dart';

class LocationData extends Equatable {
  final String id;
  final String siteId;
  final String name;
  final String? kind;

  const LocationData({
    required this.id,
    required this.siteId,
    required this.name,
    this.kind,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        id: json['id']?.toString() ?? '',
        siteId: json['site_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        kind: json['kind']?.toString(),
      );

  @override
  List<Object?> get props => [id, name];
}
