import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/dlu_rule_data.dart';
import '../../data/repositories/dlu_repository.dart';

class DluRulesScreen extends StatefulWidget {
  const DluRulesScreen({super.key});

  @override
  State<DluRulesScreen> createState() => _DluRulesScreenState();
}

class _DluRulesScreenState extends State<DluRulesScreen> {
  late Future<List<DluRuleData>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<DluRepository>().list(forceRefresh: true);
  }

  Future<void> _refresh() async {
    setState(() => _future = getIt<DluRepository>().list(forceRefresh: true));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Règles DLU'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DluRuleData>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return ErrorView(
                message: 'Impossible de charger les règles.',
                onRetry: _refresh,
              );
            }
            final list = snap.data ?? const <DluRuleData>[];
            if (list.isEmpty) {
              return const EmptyView(
                title: 'Aucune règle DLU',
                message:
                    'Aucune règle de durée limite d\'utilisation n\'est '
                    'configurée. Les règles sont gérées par votre '
                    'administrateur sur le web.',
                icon: Icons.timer_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final r = list[i];
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
                      Text('${r.packagingType} · ${r.storageCondition}',
                          style: AppTypography.bodyStrong),
                      const SizedBox(height: 4),
                      Text(
                        '${r.shelfLifeDays} jours',
                        style: AppTypography.bodyStrong
                            .copyWith(color: AppColors.brandPrimary),
                      ),
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
