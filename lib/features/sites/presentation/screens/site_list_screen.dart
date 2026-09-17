import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/site_data.dart';
import '../../data/repositories/site_repository.dart';
import '../bloc/site_list_bloc.dart';

class SiteListScreen extends StatelessWidget {
  const SiteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SiteListBloc(getIt<SiteRepository>())..add(const LoadSites()),
      child: const _SiteListView(),
    );
  }
}

class _SiteListView extends StatelessWidget {
  const _SiteListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Sites & Espaces',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<SiteListBloc>().add(const LoadSites()),
          ),
        ],
      ),
      body: BlocBuilder<SiteListBloc, SiteListState>(
        builder: (context, state) {
          if (state.status == SiteListStatus.loading && state.sites.isEmpty) {
            return const LoadingView();
          }
          if (state.status == SiteListStatus.failure) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () =>
                  context.read<SiteListBloc>().add(const LoadSites()),
            );
          }
          if (state.sites.isEmpty) {
            return const EmptyView(
              title: 'Aucun site',
              message: 'Aucun site n\'est configuré. Contactez votre '
                  'administrateur pour créer un site.',
              icon: Icons.business_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<SiteListBloc>().add(const LoadSites()),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.sites.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _SiteCard(site: state.sites[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final SiteData site;
  const _SiteCard({required this.site});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(Routes.siteLocations(site.id)),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: site.isPrimary
              ? AppColors.brandPrimary
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color:
                site.isPrimary ? AppColors.brandPrimary : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: AppTypography.bodyStrong.copyWith(
                      color: site.isPrimary
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (site.addressLine1 != null || site.city != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (site.addressLine1 != null) site.addressLine1!,
                        if (site.city != null) site.city!,
                      ].join(', '),
                      style: AppTypography.caption.copyWith(
                        color: site.isPrimary
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (site.isPrimary)
              const TypeBadge(label: 'PRINCIPAL', tone: BadgeTone.blue)
            else
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
