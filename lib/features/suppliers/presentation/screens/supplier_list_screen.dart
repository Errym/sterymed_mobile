import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
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
import '../../data/models/supplier_data.dart';
import '../../data/repositories/supplier_repository.dart';
import '../bloc/supplier_list_bloc.dart';
import '../widgets/supplier_form_sheet.dart';
import '../../../../core/utils/error_message.dart';

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

class _SupplierListView extends StatelessWidget {
  const _SupplierListView();

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
            return const EmptyView(
              title: 'Aucun fournisseur',
              message: 'Ajoutez votre premier fournisseur.',
              icon: Icons.local_shipping_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<SupplierListBloc>().add(const LoadSuppliers()),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.suppliers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final s = state.suppliers[i];
                return AnimatedListItem(
                  index: i,
                  child: _SupplierTile(
                    supplier: s,
                    onTap: () => context.go(Routes.supplierDetail(s.id)),
                    onEdit: canManage
                        ? () => SupplierFormSheet.show(context, existing: s)
                        : null,
                    onDelete: canManage
                        ? () async {
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
                              context
                                  .read<SupplierListBloc>()
                                  .add(const LoadSuppliers());
                            } catch (e) {
                              if (!context.mounted) return;
                              AppSnackbar.show(context, ErrorMessage.from(e),
                                  kind: SnackKind.error);
                            }
                          }
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final SupplierData supplier;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SupplierTile({
    required this.supplier,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  size: 18, color: AppColors.brandPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name, style: AppTypography.bodyStrong),
                  if (supplier.email != null) ...[
                    const SizedBox(height: 2),
                    Text(supplier.email!, style: AppTypography.caption),
                  ],
                  if (supplier.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(supplier.phone!, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.danger),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
