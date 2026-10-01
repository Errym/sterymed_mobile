import 'package:equatable/equatable.dart';

/// A pickable batch or location, from the `/locations` and `/batches` lookup
/// endpoints.
class StockOption extends Equatable {
  final String id;
  final String label;
  const StockOption({required this.id, required this.label});

  @override
  List<Object?> get props => [id, label];
}
