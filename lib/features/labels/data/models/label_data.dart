import 'package:equatable/equatable.dart';

class LabelData extends Equatable {
  final String id;
  final String code;
  final String status;
  final String? productName;
  final String? batchNumber;
  final String? cycleNumber;
  final String? deviceName;
  final DateTime? sterilizedAt;
  final DateTime? expiresAt;

  const LabelData({
    required this.id,
    required this.code,
    required this.status,
    this.productName,
    this.batchNumber,
    this.cycleNumber,
    this.deviceName,
    this.sterilizedAt,
    this.expiresAt,
  });

  factory LabelData.fromJson(Map<String, dynamic> json) {
    return LabelData(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      productName: json['product_name']?.toString(),
      batchNumber: json['batch_number']?.toString(),
      cycleNumber: json['cycle_number']?.toString(),
      deviceName: json['device_name']?.toString(),
      sterilizedAt: DateTime.tryParse(json['sterilized_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [
        id,
        code,
        status,
        productName,
        batchNumber,
        cycleNumber,
        deviceName,
        sterilizedAt,
        expiresAt,
      ];
}
