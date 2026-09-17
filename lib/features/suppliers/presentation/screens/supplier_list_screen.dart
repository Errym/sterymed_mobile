import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
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

class _SupplierListView extends StatelessWidget {
  const _SupplierListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Fournisseurs',
        actions: [
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
            return const LoadingView();
          }
          if (state.status == SupplierListStatus.failure) {
            return ErrorView(message: state.error ?? 'Erreur');
          }
          if (state.suppliers.isEmpty) {
            return const EmptyView(
              title: 'Aucun fournisseur',
              message: 'Ajoutez votre premier fournisseur.',
              icon: Icons.local_shipping_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final s = state.suppliers[i];
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
                    Text(s.name, style: AppTypography.bodyStrong),
                    if (s.email != null) ...[
                      const SizedBox(height: 2),
                      Text(s.email!, style: AppTypography.caption),
                    ],
                    if (s.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(s.phone!, style: AppTypography.caption),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
