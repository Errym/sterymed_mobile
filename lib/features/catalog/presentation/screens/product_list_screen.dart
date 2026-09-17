import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/product_data.dart';
import '../../data/repositories/product_repository.dart';
import '../bloc/product_list_bloc.dart';
import '../widgets/product_form_sheet.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductListBloc(getIt<ProductRepository>())
        ..add(const LoadProducts()),
      child: const _ProductListView(),
    );
  }
}

class _ProductListView extends StatelessWidget {
  const _ProductListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Catalogue produits',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => ProductFormSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSearchField(
              hint: 'Rechercher un produit...',
              onChanged: (q) =>
                  context.read<ProductListBloc>().add(SearchProducts(q)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<ProductListBloc, ProductListState>(
              builder: (context, state) {
                if (state.status == ProductListStatus.loading &&
                    state.products.isEmpty) {
                  return const LoadingView();
                }
                if (state.status == ProductListStatus.failure) {
                  return ErrorView(message: state.error ?? 'Erreur');
                }
                if (state.products.isEmpty) {
                  return const EmptyView(
                    title: 'Aucun produit',
                    message: 'Ajoutez votre premier produit.',
                    icon: Icons.inventory_2_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final p = state.products[i];
                    return _ProductTile(
                      product: p,
                      onEdit: () => ProductFormSheet.show(context, existing: p),
                      onDelete: () async {
                        final ok = await ConfirmationDialog.show(
                          context,
                          title: 'Supprimer le produit ?',
                          message: p.name,
                          confirmLabel: 'Supprimer',
                          isDestructive: true,
                        );
                        if (ok && context.mounted) {
                          context.read<ProductListBloc>().add(DeleteProduct(p.id));
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductData product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${product.reference} · Seuil ${product.minThreshold} ${product.unit}',
                  style: AppTypography.caption,
                ),
                if (product.isSterilizable) ...[
                  const SizedBox(height: 4),
                  Text('Stérilisable', style: AppTypography.caption.copyWith(color: AppColors.success)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
