import 'package:equatable/equatable.dart';

class SiteData extends Equatable {
  final String id;
  final String name;
  final String? addressLine1;
  final String? city;
  final bool isPrimary;

  const SiteData({
    required this.id,
    required this.name,
    this.addressLine1,
    this.city,
    this.isPrimary = false,
  });

  /// Handles multiple backend shapes for the address and primary flag:
  /// - `address_line1` / `address1` / `address`
  /// - `city` / `town` / `locality`
  /// - `is_primary` as bool OR `"1"` / `"true"` (string)
  factory SiteData.fromJson(Map<String, dynamic> json) {
    final rawPrimary = json['is_primary'];
    final isPrimary = rawPrimary == true ||
        rawPrimary == 1 ||
        rawPrimary == '1' ||
        rawPrimary == 'true';

    return SiteData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      addressLine1: (json['address_line1'] ??
              json['address1'] ??
              json['address'])
          ?.toString(),
      city: (json['city'] ?? json['town'] ?? json['locality'])?.toString(),
      isPrimary: isPrimary,
    );
  }

  @override
  List<Object?> get props => [id, name, isPrimary];
}
