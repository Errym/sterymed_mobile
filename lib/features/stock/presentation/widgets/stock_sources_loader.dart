import 'package:flutter/material.dart';

import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/models/stock_option.dart';
import '../../data/pending_stock_delta.dart';
import '../../data/repositories/stock_repository.dart';

/// Everything a stock movement screen needs to offer only choices that can
/// work: the rows that really have stock, the active places, the known lots
/// (for adding found stock), and what this phone has queued but not sent.
class StockSourcesData {
  final List<StockLevelData> rows;
  final List<StockOption> locations;
  final List<StockOption> batches;
  final PendingStockDelta pending;

  const StockSourcesData({
    required this.rows,
    required this.locations,
    required this.batches,
    required this.pending,
  });
}

class StockSourcesLoader extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    StockSourcesData data,
    Future<void> Function() reload,
  )
  builder;

  const StockSourcesLoader({super.key, required this.builder});

  @override
  State<StockSourcesLoader> createState() => _StockSourcesLoaderState();
}

class _StockSourcesLoaderState extends State<StockSourcesLoader> {
  StockSourcesData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PendingStockDelta _pending() {
    if (!getIt.isRegistered<OutboxStore>()) return PendingStockDelta.empty;
    return PendingStockDelta.fromItems(getIt<OutboxStore>().all());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = _data == null;
        _error = null;
      });
    }
    try {
      final repo = getIt<StockRepository>();
      final rows = await repo.listSources();
      final options = await repo.listOptions(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _data = StockSourcesData(
          rows: rows,
          locations: options.locations,
          batches: options.batches,
          pending: _pending(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final data = _data;
    if (_error != null && data == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Impossible de charger les données de stock',
                style: AppTypography.bodyStrong,
              ),
              const SizedBox(height: 4),
              Text(_error!, style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Réessayer'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widget.builder(context, data!, _load);
  }
}
