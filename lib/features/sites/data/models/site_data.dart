import 'package:equatable/equatable.dart';

class SiteData extends Equatable {
  final String id;
  final String name;
  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final String? city;
  final String? countryCode;
  final String? timezone;
  final bool isPrimary;
  final bool archived;

  /// How much the site holds, as the server counts it. Null when the server
  /// did not send the figure (never shown as zero).
  final int? roomsCount;
  final int? storageLocationsCount;
  final int? devicesCount;

  const SiteData({
    required this.id,
    required this.name,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.city,
    this.countryCode,
    this.timezone,
    this.isPrimary = false,
    this.archived = false,
    this.roomsCount,
    this.storageLocationsCount,
    this.devicesCount,
  });

  /// "12 rue de la Paix, 75008 Paris": what a map application understands.
  /// Null when the site has no usable address at all.
  String? get fullAddress {
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    final street = [clean(addressLine1), clean(addressLine2)]
        .whereType<String>()
        .join(', ');
    final town =
        [clean(postalCode), clean(city)].whereType<String>().join(' ');
    final out = [if (street.isNotEmpty) street, if (town.isNotEmpty) town]
        .join(', ');
    return out.isEmpty ? null : out;
  }

  static int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

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
      addressLine2: json['address_line2']?.toString(),
      postalCode: json['postal_code']?.toString(),
      city: (json['city'] ?? json['town'] ?? json['locality'])?.toString(),
      countryCode: json['country_code']?.toString(),
      timezone: json['timezone']?.toString(),
      isPrimary: isPrimary,
      archived: json['archived_at'] != null,
      roomsCount: _int(json['rooms_count']),
      storageLocationsCount: _int(json['storage_locations_count']),
      devicesCount: _int(json['devices_count']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        isPrimary,
        archived,
        roomsCount,
        storageLocationsCount,
        devicesCount,
      ];
}
