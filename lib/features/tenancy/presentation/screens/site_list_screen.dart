import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/site_data.dart';
import '../../data/repositories/site_repository.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  late Future<List<SiteData>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<SiteRepository>().list();
  }

  Future<void> _refresh() async {
    setState(() => _future = getIt<SiteRepository>().list());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Sites & Espaces Cliniques'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SiteData>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return ErrorView(
                message: 'Impossible de charger les sites.',
                onRetry: _refresh,
              );
            }
            final sites = snap.data ?? const <SiteData>[];
            if (sites.isEmpty) {
              return const EmptyView(
                title: 'Aucun site',
                message: 'Aucun site clinique configuré.',
                icon: Icons.business_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: sites.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _SiteCard(site: sites[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final SiteData site;
  const _SiteCard({required this.site});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  (site.kind ?? 'SITE').toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.business, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            site.name,
            style: AppTypography.sectionTitle.copyWith(color: Colors.white),
          ),
          if (site.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    site.address!,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatChip(label: '${site.roomCount} salle(s)'),
              _StatChip(label: '${site.deviceCount} appareil(s)'),
              _StatChip(label: '${site.armoryCount} armoire(s)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: Colors.white),
      ),
    );
  }
}
