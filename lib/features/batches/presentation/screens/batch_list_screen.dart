import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/batch_data.dart';
import '../../data/repositories/batch_repository.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  late Future<List<BatchData>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<BatchRepository>().list(forceRefresh: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = getIt<BatchRepository>().list(forceRefresh: true);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Lots',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<BatchData>>(
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
            final list = snap.data ?? const <BatchData>[];
            if (list.isEmpty) {
              return const EmptyView(
                title: 'Aucun lot',
                message:
                    'Les lots sont créés automatiquement lors de la '
                    'réception d\'une commande fournisseur.',
                icon: Icons.inventory_2_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final b = list[i];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.batchNumber, style: AppTypography.bodyStrong),
                      if (b.productName != null) ...[
                        const SizedBox(height: 2),
                        Text(b.productName!, style: AppTypography.caption),
                      ],
                      const SizedBox(height: 4),
                      Text(b.id,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
