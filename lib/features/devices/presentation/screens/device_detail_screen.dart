import 'package:flutter/material.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/buttons/danger_button.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/device_detail.dart';
import '../../data/repositories/device_detail_repository.dart';
import '../widgets/device_field.dart';
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
    _future = getIt<DeviceDetailRepository>().show(widget.deviceId);
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimaryLight,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_outlined,
                          color: AppColors.brandPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name, style: AppTypography.sectionTitle),
                            const SizedBox(height: 4),
                            if (d.status != null)
                              TypeBadge(
                                label: d.status!.toUpperCase(),
                                tone: d.status == 'active'
                                    ? BadgeTone.green
                                    : BadgeTone.gray,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Identification ──
                const SectionHeader(title: 'Identification'),
                DeviceField(label: 'N° de série', value: d.serialNumber),
                DeviceField(label: 'Fabricant', value: d.manufacturer),
                DeviceField(label: 'Modèle', value: d.model),
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

                // ── Localisation ──
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Localisation'),
                DeviceField(label: 'Site', value: d.siteName),
                const SizedBox(height: AppSpacing.lg),

                // ── Notes ──
                if (d.notes != null && d.notes!.isNotEmpty) ...[
                  const SectionHeader(title: 'Notes'),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
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
