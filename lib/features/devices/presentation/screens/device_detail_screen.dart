import 'package:flutter/material.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/buttons/danger_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/site_names.dart';
import '../../data/models/device_detail.dart';
import '../../data/repositories/device_detail_repository.dart';
import '../widgets/device_form_sheet.dart';
import '../widgets/device_maintenance_section.dart';
import '../widgets/device_programmes_section.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late Future<DeviceDetail> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // The API sends the site's id only: resolve its name for display.
    _future = Future.wait([
      getIt<DeviceDetailRepository>().show(widget.deviceId),
      loadSiteNames(),
    ]).then((r) {
      final d = r[0] as DeviceDetail;
      return d.withSiteName((r[1] as Map<String, String>)[d.siteId]);
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _edit() async {
    final result = await DeviceFormSheet.show(
      context,
      existingId: widget.deviceId,
    );
    if (result == true && mounted) await _refresh();
  }

  Future<void> _delete() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cet appareil ?',
      message:
          'Cette action est irréversible. Les cycles liés à cet appareil ne '
          'seront pas supprimés.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await getIt<DeviceDetailRepository>().destroy(widget.deviceId);
      if (!mounted) return;
      AppSnackbar.show(context, 'Appareil supprimé.', kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('devices.manage');

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Détail de l\'appareil',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: _edit,
            ),
        ],
      ),
      body: FutureBuilder<DeviceDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError || !snap.hasData) {
            return ErrorView(
              message: 'Impossible de charger cet appareil.',
              onRetry: _refresh,
            );
          }
          final d = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // ── Header ──
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          EntityMark.icon(
                            Icons.precision_manufacturing_outlined,
                            background: d.isActive
                                ? AppColors.brandPrimaryLight
                                : AppColors.surfaceWell,
                            foreground: d.isActive
                                ? AppColors.brandPrimaryDark
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.kindLabel.toUpperCase(),
                                  style: AppTypography.eyebrow,
                                ),
                                Text(d.name,
                                    style: AppTypography.sectionTitle),
                                if (d.makeAndModel != null)
                                  Text(d.makeAndModel!,
                                      style: AppTypography.caption),
                              ],
                            ),
                          ),
                          if (d.status != null)
                            TypeBadge(
                              label: d.statusLabel,
                              tone: switch (d.status) {
                                'active' => BadgeTone.green,
                                'maintenance' => BadgeTone.orange,
                                _ => BadgeTone.gray,
                              },
                            ),
                        ],
                      ),
                      if (d.status == 'maintenance' ||
                          d.status == 'decommissioned') ...[
                        const SizedBox(height: AppSpacing.md),
                        NoteStrip(
                          icon: Icons.info_outline,
                          text: d.status == 'maintenance'
                              ? 'Cet appareil est en maintenance : il ne '
                                  'devrait pas être utilisé pour un cycle.'
                              : 'Cet appareil est hors service.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Identification ──
                FormCard(
                  title: 'Identification',
                  gap: AppSpacing.xs,
                  children: [
                    DetailRow(Icons.tag, 'N° de série', d.serialNumber ?? '—'),
                    DetailRow(Icons.factory_outlined, 'Fabricant',
                        d.manufacturer ?? '—'),
                    DetailRow(Icons.memory_outlined, 'Modèle', d.model ?? '—'),
                    DetailRow(
                      Icons.event_available_outlined,
                      'Mise en service',
                      d.commissionedAt == null
                          ? '—'
                          : AppDateFormatter.date(d.commissionedAt!),
                    ),
                    if (d.decommissionedAt != null)
                      DetailRow(
                        Icons.event_busy_outlined,
                        'Mise hors service',
                        AppDateFormatter.date(d.decommissionedAt!),
                        color: AppColors.danger,
                      ),
                    DetailRow(Icons.business_outlined, 'Site',
                        d.siteName ?? '—'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Programmes ──
                DeviceProgrammesSection(
                  deviceId: widget.deviceId,
                  canManage: canManage,
                ),

                // ── Maintenance ──
                const SizedBox(height: AppSpacing.lg),
                DeviceMaintenanceSection(
                  deviceId: widget.deviceId,
                  canManage: canManage,
                ),

                // ── Notes ──
                if (d.notes != null && d.notes!.isNotEmpty) ...[
                  const SectionHeader(title: 'Notes'),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(d.notes!, style: AppTypography.body),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (canManage) ...[
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Modifier cet appareil',
                    icon: Icons.edit_outlined,
                    onPressed: _edit,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DangerButton(
                    label: 'Supprimer',
                    icon: Icons.delete_outline,
                    onPressed: _delete,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}
