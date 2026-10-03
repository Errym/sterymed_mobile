import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
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
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<SiteListBloc>().add(const LoadSites()),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: NoteStrip(
              icon: Icons.info_outline,
              text: 'Les sites et espaces sont gérés depuis l\'interface web '
                  'par un administrateur. Cette vue est en lecture seule.',
            ),
          ),
          Expanded(
            child: BlocBuilder<SiteListBloc, SiteListState>(
              builder: (context, state) {
                if (state.status == SiteListStatus.loading &&
                    state.sites.isEmpty) {
                  return const ListSkeleton();
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
                    message: 'Aucun site n\'est configuré.\n\n'
                        'Contactez votre administrateur pour créer le '
                        'premier site depuis l\'interface web.',
                    icon: Icons.business_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      context.read<SiteListBloc>().add(const LoadSites()),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: state.sites.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => AnimatedListItem(
                      index: i,
                      child: _SiteCard(site: state.sites[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final SiteData site;
  const _SiteCard({required this.site});

  @override
  Widget build(BuildContext context) {
    final address = site.fullAddress;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityMark.icon(
                Icons.business_outlined,
                background:
                    site.isPrimary ? AppColors.navyHeader : AppColors.surfaceWell,
                foreground:
                    site.isPrimary ? Colors.white : AppColors.navyHeader,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.isPrimary ? 'SITE PRINCIPAL' : 'SITE',
                      style: AppTypography.eyebrow,
                    ),
                    Text(site.name, style: AppTypography.cardTitle),
                    if (address != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(address, style: AppTypography.caption),
                      ),
                  ],
                ),
              ),
              if (site.archived)
                const TypeBadge(label: 'ARCHIVÉ', tone: BadgeTone.gray)
              else if (site.isPrimary)
                const TypeBadge(label: 'PRINCIPAL', tone: BadgeTone.blue),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (site.roomsCount != null)
                InfoTag(
                  '${site.roomsCount} salle${site.roomsCount == 1 ? '' : 's'}',
                  icon: Icons.meeting_room_outlined,
                ),
              if (site.storageLocationsCount != null)
                InfoTag(
                  '${site.storageLocationsCount} emplacement'
                  '${site.storageLocationsCount == 1 ? '' : 's'}',
                  icon: Icons.shelves,
                ),
              if (site.devicesCount != null)
                InfoTag(
                  '${site.devicesCount} appareil'
                  '${site.devicesCount == 1 ? '' : 's'}',
                  icon: Icons.precision_manufacturing_outlined,
                ),
              if ((site.timezone ?? '').isNotEmpty)
                InfoTag(site.timezone!, icon: Icons.schedule),
            ],
          ),
          if (address != null) ...[
            const SizedBox(height: AppSpacing.md),
            ContactActions(address: address),
          ],
        ],
      ),
    );
  }
}
