import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../../purchases/data/repositories/purchase_repository.dart';
import '../../data/models/supplier_data.dart';
import '../../data/models/supplier_order_stats.dart';
import '../../data/repositories/supplier_repository.dart';
import '../bloc/supplier_list_bloc.dart';
import '../widgets/supplier_form_sheet.dart';

class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SupplierListBloc(getIt<SupplierRepository>())
        ..add(const LoadSuppliers()),
      child: const _SupplierListView(),
    );
  }
}

class _SupplierListView extends StatefulWidget {
  const _SupplierListView();

  @override
  State<_SupplierListView> createState() => _SupplierListViewState();
}

class _SupplierListViewState extends State<_SupplierListView> {
  String _query = '';

  /// Per-supplier order figures. Only filled when the order list came back
  /// complete: with more orders than one page, a count would be a guess.
  Map<String, SupplierOrderStats>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final page = await getIt<PurchaseRepository>().list(forceRefresh: true);
      if (!mounted) return;
      setState(() => _stats =
          page.hasMore ? null : SupplierOrderStats.bySupplier(page.items));
    } catch (_) {
      if (mounted) setState(() => _stats = null);
    }
  }

  bool _matches(SupplierData s) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.name.toLowerCase().contains(q) ||
        (s.email ?? '').toLowerCase().contains(q) ||
        (s.phone ?? '').toLowerCase().contains(q) ||
        (s.address ?? '').toLowerCase().contains(q);
  }

  Future<void> _delete(BuildContext context, SupplierData s) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer ce fournisseur ?',
      message: s.name,
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await getIt<SupplierRepository>().destroy(s.id);
      if (!context.mounted) return;
      context.read<SupplierListBloc>().add(const LoadSuppliers());
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('suppliers.manage');

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Fournisseurs',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nouveau fournisseur',
              onPressed: () => SupplierFormSheet.show(context),
            ),
        ],
      ),
      body: BlocBuilder<SupplierListBloc, SupplierListState>(
        builder: (context, state) {
          if (state.status == SupplierListStatus.loading &&
              state.suppliers.isEmpty) {
            return const ListSkeleton();
          }
          if (state.status == SupplierListStatus.failure) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () =>
                  context.read<SupplierListBloc>().add(const LoadSuppliers()),
            );
          }
          if (state.suppliers.isEmpty) {
            return EmptyView(
              title: 'Aucun fournisseur',
              message: canManage
                  ? 'Ajoutez votre premier fournisseur pour pouvoir lui '
                      'passer commande.'
                  : 'Aucun fournisseur n\'est enregistré pour le moment.',
              icon: Icons.local_shipping_outlined,
              action: canManage
                  ? FilledButton.icon(
                      onPressed: () => SupplierFormSheet.show(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nouveau fournisseur'),
                    )
                  : null,
            );
          }
          final shown = state.suppliers.where(_matches).toList();
          return RefreshIndicator(
            onRefresh: () async {
              context.read<SupplierListBloc>().add(const LoadSuppliers());
              await _loadStats();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                AppSearchField(
                  hint: 'Rechercher un fournisseur...',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${state.suppliers.length} FOURNISSEUR'
                        '${state.suppliers.length > 1 ? 'S' : ''}',
                        style: AppTypography.eyebrow,
                      ),
                    ),
                    if (_stats != null)
                      Text(
                        '${_stats!.values.fold<int>(0, (s, e) => s + e.open)}'
                        ' commande(s) en cours',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: EmptyView(
                      title: 'Aucun résultat',
                      message: 'Aucun fournisseur ne correspond à cette '
                          'recherche.',
                      icon: Icons.search_off_outlined,
                    ),
                  ),
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AnimatedListItem(
                      index: i,
                      child: _SupplierCard(
                        supplier: shown[i],
                        stats: _stats?[shown[i].id],
                        statsKnown: _stats != null,
                        onTap: () => context
                            .openRoute(Routes.supplierDetail(shown[i].id)),
                        onEdit: canManage
                            ? () => SupplierFormSheet.show(
                                  context,
                                  existing: shown[i],
                                )
                            : null,
                        onDelete:
                            canManage ? () => _delete(context, shown[i]) : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierData supplier;
  final SupplierOrderStats? stats;
  final bool statsKnown;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.stats,
    required this.statsKnown,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    final open = stats?.open ?? 0;
    return EntityCard(
      onTap: onTap,
      mark: EntityMark.initials(EntityMark.initialsOf(s.name)),
      eyebrow: 'FOURNISSEUR',
      title: s.name,
      subtitle: (s.address ?? '').trim().isEmpty ? null : s.address!.trim(),
      trailing: (onEdit == null && onDelete == null)
          ? const Icon(Icons.chevron_right, color: AppColors.textTertiary)
          : PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete?.call(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
      tags: [
        if ((s.phone ?? '').trim().isNotEmpty)
          InfoTag(s.phone!.trim(), icon: Icons.call_outlined),
        if ((s.email ?? '').trim().isNotEmpty)
          InfoTag(s.email!.trim(), icon: Icons.mail_outline),
        if (statsKnown && open > 0)
          InfoTag(
            '$open commande${open > 1 ? 's' : ''} en cours',
            icon: Icons.local_shipping_outlined,
            color: AppColors.warning,
          ),
        if (statsKnown && stats?.lastOrderedAt != null)
          InfoTag(
            'Dernière commande ${AppDateFormatter.date(stats!.lastOrderedAt!)}',
            icon: Icons.history,
          ),
        if (statsKnown && stats == null)
          const InfoTag('Aucune commande', icon: Icons.history),
      ],
    );
  }
}
