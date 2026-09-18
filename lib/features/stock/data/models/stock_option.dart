import 'package:equatable/equatable.dart';

/// A pickable batch or location, derived from the stock-levels list.
/// The backend has no /batches or /locations endpoints — but /stock-levels
/// exposes both batch_id + batch_number and location_id + location_name,
/// so we build the option lists from that.
class StockOption extends Equatable {
  final String id;
  final String label;
  const StockOption({required this.id, required this.label});

  @override
  List<Object?> get props => [id, label];
}
