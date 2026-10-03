import 'package:equatable/equatable.dart';

/// Where a batch is, and how much, as answered by `GET /v1/lookups/code`.
class LookupLocation extends Equatable {
  final String locationId;
  final String locationName;
  final bool archived;
  final int quantity;

  const LookupLocation({
    required this.locationId,
    required this.locationName,
    required this.archived,
    required this.quantity,
  });

  factory LookupLocation.fromJson(Map<String, dynamic> json) => LookupLocation(
    locationId: json['location_id']?.toString() ?? '',
    locationName: json['location_name']?.toString() ?? '',
    archived: json['archived'] == true,
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [locationId, quantity, archived];
}

class LookupBatch extends Equatable {
  final String id;
  final String batchNumber;
  final DateTime? expiryDate;
  final String status;
  final bool isExpired;
  final int qtyOnHand;
  final List<LookupLocation> locations;

  const LookupBatch({
    required this.id,
    required this.batchNumber,
    required this.status,
    required this.isExpired,
    required this.qtyOnHand,
    required this.locations,
    this.expiryDate,
  });

  bool get isQuarantined => status == 'quarantined';

  factory LookupBatch.fromJson(Map<String, dynamic> json) {
    final locs = json['locations'];
    return LookupBatch(
      id: json['id']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'active',
      isExpired: json['is_expired'] == true,
      qtyOnHand: (json['qty_on_hand'] as num?)?.toInt() ?? 0,
      locations: locs is List
          ? locs
                .whereType<Map>()
                .map((e) => LookupLocation.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [id, qtyOnHand, status, locations];
}

class LookupProduct extends Equatable {
  final String id;
  final String name;
  final String reference;
  final String unit;
  final String? barcode;
  final int minThreshold;
  final int qtyOnHand;
  final List<LookupBatch> batches;

  const LookupProduct({
    required this.id,
    required this.name,
    required this.reference,
    required this.unit,
    required this.minThreshold,
    required this.qtyOnHand,
    required this.batches,
    this.barcode,
  });

  bool get isLow => minThreshold > 0 && qtyOnHand <= minThreshold;

  factory LookupProduct.fromJson(Map<String, dynamic> json) {
    final batches = json['batches'];
    return LookupProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'u',
      barcode: json['barcode']?.toString(),
      minThreshold: (json['min_threshold'] as num?)?.toInt() ?? 0,
      qtyOnHand: (json['qty_on_hand'] as num?)?.toInt() ?? 0,
      batches: batches is List
          ? batches
                .whereType<Map>()
                .map((e) => LookupBatch.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [id, qtyOnHand, batches];
}

/// What a code resolved to. [matchedBy] is `barcode`, `reference` or
/// `batch_number`; two products can share a batch number, hence a list.
class CodeLookup extends Equatable {
  final String code;
  final String matchedBy;
  final List<LookupProduct> products;

  const CodeLookup({
    required this.code,
    required this.matchedBy,
    required this.products,
  });

  bool get matchedBatch => matchedBy == 'batch_number';

  factory CodeLookup.fromJson(Map<String, dynamic> json) {
    final products = json['products'];
    return CodeLookup(
      code: json['code']?.toString() ?? '',
      matchedBy: json['matched_by']?.toString() ?? '',
      products: products is List
          ? products
                .whereType<Map>()
                .map((e) => LookupProduct.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [code, matchedBy, products];
}
