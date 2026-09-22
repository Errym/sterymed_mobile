import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../cycles/data/repositories/device_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = getIt<DeviceDetailRepository>().list(forceRefresh: true);
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
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Appareils & Programmes',
        actions: [
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
              return const LoadingView();
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
                action: FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvel appareil'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: devices.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => AnimatedListItem(
                index: i,
                child: _DeviceCard(
                  device: devices[i],
                  onTap: () async {
                    final changed = await context.push<bool>(
                      '/app/devices/${devices[i].id}',
                    );
                    if (changed == true && mounted) _refresh();
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
  final VoidCallback? onTap;
  const _DeviceCard({required this.device, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: AppTypography.bodyStrong),
                    if (device.model != null) ...[
                      const SizedBox(height: 2),
                      Text(device.model!, style: AppTypography.caption),
                    ],
                    if (device.serialNumber != null) ...[
                      const SizedBox(height: 2),
                      Text('SN: ${device.serialNumber!}',
                          style: AppTypography.caption),
                    ],
                  ],
                ),
              ),
              if (device.status != null)
                TypeBadge(
                  label: device.status!.toUpperCase(),
                  tone: device.status == 'active'
                      ? BadgeTone.green
                      : BadgeTone.gray,
                ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
