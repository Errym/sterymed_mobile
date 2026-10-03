import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../../cycles/data/repositories/device_repository.dart';
import '../../data/site_names.dart';
import '../../data/models/device_detail.dart';
import '../../data/repositories/device_detail_repository.dart';
import '../widgets/device_form_sheet.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late Future<List<DeviceDetail>> _future;
  Map<String, String> _sites = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = getIt<DeviceDetailRepository>().list(forceRefresh: true);
    loadSiteNames().then((m) {
      if (mounted) setState(() => _sites = m);
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _create() async {
    final ok = await DeviceFormSheet.show(context);
    if (ok == true) {
      getIt<DeviceRepository>().invalidateCache();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('devices.manage');

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Appareils & Programmes',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nouvel appareil',
              onPressed: _create,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DeviceDetail>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ListSkeleton();
            }
            if (snap.hasError) {
              return ErrorView(
                message: 'Impossible de charger les appareils.',
                onRetry: _refresh,
              );
            }
            final devices = snap.data ?? const <DeviceDetail>[];
            if (devices.isEmpty) {
              return EmptyView(
                title: 'Aucun appareil',
                message: 'Ajoutez votre premier autoclave.',
                icon: Icons.precision_manufacturing_outlined,
                action: canManage
                    ? FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nouvel appareil'),
                      )
                    : null,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              itemCount: devices.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => AnimatedListItem(
                index: i,
                child: _DeviceCard(
                  device: devices[i],
                  siteName: _sites[devices[i].siteId],
                  onTap: () async {
                    // Reload whatever way the user comes back (Back button,
                    // delete, edit): the detail screen may have changed or
                    // removed this device, and Back returns no result at all.
                    await context.push<bool>('/app/devices/${devices[i].id}');
                    if (mounted) _refresh();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceDetail device;
  final String? siteName;
  final VoidCallback? onTap;
  const _DeviceCard({required this.device, this.siteName, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = device;
    final active = d.isActive;
    return EntityCard(
      onTap: onTap,
      mark: EntityMark.icon(
        d.kind == 'sealer'
            ? Icons.local_fire_department_outlined
            : Icons.precision_manufacturing_outlined,
        background: active ? AppColors.brandPrimaryLight : AppColors.surfaceWell,
        foreground: active ? AppColors.brandPrimaryDark : AppColors.textSecondary,
      ),
      eyebrow: d.kindLabel.toUpperCase(),
      title: d.name,
      subtitle: d.makeAndModel,
      trailing: d.status == null
          ? null
          : TypeBadge(
              label: d.statusLabel,
              tone: switch (d.status) {
                'active' => BadgeTone.green,
                'maintenance' => BadgeTone.orange,
                _ => BadgeTone.gray,
              },
            ),
      tags: [
        if ((d.serialNumber ?? '').isNotEmpty)
          InfoTag('N° ${d.serialNumber}', icon: Icons.tag),
        if ((siteName ?? '').isNotEmpty)
          InfoTag(siteName!, icon: Icons.business_outlined),
        if (d.commissionedAt != null)
          InfoTag(
            'En service depuis ${AppDateFormatter.date(d.commissionedAt!)}',
            icon: Icons.event_available_outlined,
          ),
      ],
    );
  }
}
