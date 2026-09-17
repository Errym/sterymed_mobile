import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/location_data.dart';
import '../../data/repositories/location_repository.dart';

class LocationListScreen extends StatefulWidget {
  final String siteId;
  const LocationListScreen({super.key, required this.siteId});

  @override
  State<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  late Future<List<LocationData>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LocationRepository>()
        .listForSite(widget.siteId, forceRefresh: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = getIt<LocationRepository>()
          .listForSite(widget.siteId, forceRefresh: true);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Salles & Emplacements',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<LocationData>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return ErrorView(
                message: 'Impossible de charger les emplacements.',
                onRetry: _refresh,
              );
            }
            final list = snap.data ?? const <LocationData>[];
            if (list.isEmpty) {
              return const EmptyView(
                title: 'Aucun emplacement',
                message:
                    'Aucune salle ou zone stérile pour ce site. Contactez '
                    'votre administrateur pour configurer les emplacements.',
                icon: Icons.meeting_room_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final l = list[i];
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
                            Text(l.name, style: AppTypography.bodyStrong),
                            const SizedBox(height: 4),
                            Text(l.id,
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                      if (l.kind != null)
                        TypeBadge(
                          label: l.kind!.toUpperCase(),
                          tone: BadgeTone.blue,
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
