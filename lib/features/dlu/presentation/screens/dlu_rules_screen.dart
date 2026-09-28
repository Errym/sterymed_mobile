import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../data/models/dlu_rule_data.dart';
import '../../data/repositories/dlu_repository.dart';
import '../widgets/dlu_rule_form_sheet.dart';

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

  Future<void> _delete(DluRuleData rule) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cette règle DLU ?',
      message: rule.existingLabelsCount > 0
          ? '${rule.packagingType} · ${rule.storageCondition}\n\n'
              '${rule.existingLabelsCount} étiquette(s) existante(s) '
              'utilisent cette règle. Elles ne seront pas affectées, mais '
              'plus aucune nouvelle étiquette ne pourra s\'en servir.'
          : '${rule.packagingType} · ${rule.storageCondition}',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await getIt<DluRepository>().destroy(rule.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Règle DLU supprimée.',
          kind: SnackKind.success);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('labels.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Règles DLU',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nouvelle règle',
              onPressed: () async {
                final ok = await DluRuleFormSheet.show(context);
                if (ok == true) await _refresh();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DluRuleData>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ListSkeleton();
            }
            if (snap.hasError) {
              return ErrorView(
                message: 'Impossible de charger les règles.',
                onRetry: _refresh,
              );
            }
            final list = snap.data ?? const <DluRuleData>[];
            if (list.isEmpty) {
              return EmptyView(
                title: 'Aucune règle DLU',
                message: canManage
                    ? 'Créez votre première règle de durée limite '
                        'd\'utilisation.'
                    : 'Aucune règle de durée limite d\'utilisation n\'est '
                        'configurée.',
                icon: Icons.timer_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final r = list[i];
                return AnimatedListItem(
                  index: i,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${r.packagingType} · ${r.storageCondition}',
                                style: AppTypography.bodyStrong,
                              ),
                            ),
                            if (canManage) ...[
                              InkWell(
                                onTap: () async {
                                  final ok = await DluRuleFormSheet.show(
                                    context,
                                    existing: r,
                                  );
                                  if (ok == true) await _refresh();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              InkWell(
                                onTap: () => _delete(r),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline,
                                      size: 20, color: AppColors.danger),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r.shelfLifeDays} jours',
                          style: AppTypography.bodyStrong
                              .copyWith(color: AppColors.brandPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r.existingLabelsCount} étiquette(s) utilisent cette règle',
                          style: AppTypography.caption,
                        ),
                        if (r.lastUpdatedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Modifiée le '
                            '${DateFormat('dd/MM/yyyy').format(r.lastUpdatedAt!)}'
                            '${r.lastUpdatedBy != null ? ' par ${r.lastUpdatedBy}' : ''}',
                            style: AppTypography.caption,
                          ),
                        ],
                        if (r.lastReason != null &&
                            r.lastReason!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(r.lastReason!, style: AppTypography.caption),
                        ],
                      ],
                    ),
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
