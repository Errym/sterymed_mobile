import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';

/// There is no backend /batches endpoint (confirmed 404,
/// docs/BACKEND_BUGS.md#BUG-003) — /stock-levels already carries
/// batch_id/batch_number/expiry_date per row, so this screen is that
/// same data, filtered to batched rows and sorted by expiry — the same
/// "derive from stock-levels" workaround already used for locations
/// (BUG-002) in stock_adjust_screen.dart and elsewhere.
class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  late Future<List<StockLevelData>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = getIt<StockRepository>()
        .listLevels(forceRefresh: true)
        .then((levels) {
      final batched = levels.where((l) => l.batchNumber != null).toList()
        ..sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
      return batched;
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Lots'),
      body: FutureBuilder<List<StockLevelData>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(
              message: 'Impossible de charger les lots.',
              onRetry: _refresh,
            );
          }
          final batches = snap.data ?? const [];
          if (batches.isEmpty) {
            return const EmptyView(
              title: 'Aucun lot',
              message: 'Les lots apparaissent ici dès qu\'un stock avec '
                  'numéro de lot est réceptionné.',
              icon: Icons.inventory_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: batches.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => AnimatedListItem(
                index: i,
                child: _BatchTile(level: batches[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final StockLevelData level;
  const _BatchTile({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: level.isExpired
              ? AppColors.danger.withValues(alpha: 0.4)
              : level.isNearExpiry
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Lot ${level.batchNumber}',
                    style: AppTypography.bodyStrong),
              ),
              Text('${level.qty} ${level.unit}',
                  style: AppTypography.bodyStrong
                      .copyWith(color: AppColors.brandPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${level.productName} · ${level.locationName}',
              style: AppTypography.caption),
          if (level.expiryDate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TypeBadge(
              label: level.isExpired
                  ? 'Périmé'
                  : 'DLC ${DateFormat('dd/MM/yy').format(level.expiryDate!)}',
              tone: level.isExpired
                  ? BadgeTone.red
                  : level.isNearExpiry
                      ? BadgeTone.orange
                      : BadgeTone.green,
            ),
          ],
        ],
      ),
    );
  }
}
