import 'package:flutter/material.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
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
import '../../../cycles/data/models/device_program_data.dart';
import '../../../cycles/data/repositories/device_program_repository.dart';
import '../../data/models/device_detail.dart';
import '../../data/repositories/device_detail_repository.dart';
import '../widgets/device_form_sheet.dart';
import '../widgets/programme_form_sheet.dart';

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
      AppSnackbar.show(context, 'Appareil supprimé.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
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
                _Field(label: 'N° de série', value: d.serialNumber),
                _Field(label: 'Fabricant', value: d.manufacturer),
                _Field(label: 'Modèle', value: d.model),
                const SizedBox(height: AppSpacing.lg),

                // ── Programmes ──
                _ProgrammesSection(
                  deviceId: widget.deviceId,
                  canManage: canManage,
                ),

                // ── Localisation ──
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Localisation'),
                _Field(label: 'Site', value: d.siteName),
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

// ─────────────────────────────────────────────────────────────────────────────
// Programme section
// ─────────────────────────────────────────────────────────────────────────────

class _ProgrammesSection extends StatefulWidget {
  final String deviceId;
  final bool canManage;
  const _ProgrammesSection({required this.deviceId, required this.canManage});

  @override
  State<_ProgrammesSection> createState() => _ProgrammesSectionState();
}

class _ProgrammesSectionState extends State<_ProgrammesSection> {
  List<DeviceProgramData> _programs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final programs = await getIt<DeviceProgramRepository>()
          .list(widget.deviceId, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _programs = programs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _add() async {
    final ok = await ProgrammeFormSheet.show(
      context,
      deviceId: widget.deviceId,
    );
    if (ok == true) await _load();
  }

  Future<void> _edit(DeviceProgramData p) async {
    final ok = await ProgrammeFormSheet.show(
      context,
      deviceId: widget.deviceId,
      existing: p,
    );
    if (ok == true) await _load();
  }

  Future<void> _delete(DeviceProgramData p) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer ce programme ?',
      message: p.displayLabel,
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await getIt<DeviceProgramRepository>().destroy(
        deviceId: widget.deviceId,
        programId: p.id,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Programme supprimé.',
          kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Programmes de stérilisation (${_programs.length})',
          trailing: widget.canManage
              ? IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Ajouter un programme',
                  onPressed: _loading ? null : _add,
                )
              : null,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(_error!, style: AppTypography.caption),
          )
        else if (_programs.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aucun programme défini',
                  style: AppTypography.bodyStrong,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ajoutez au moins un programme pour pouvoir créer des '
                  'cycles avec cet appareil.',
                  style: AppTypography.caption,
                ),
                if (widget.canManage) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter un programme'),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ..._programs.map((p) => _ProgrammeRow(
                program: p,
                onEdit: widget.canManage ? () => _edit(p) : null,
                onDelete: widget.canManage ? () => _delete(p) : null,
              )),
      ],
    );
  }
}

class _ProgrammeRow extends StatelessWidget {
  final DeviceProgramData program;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ProgrammeRow({
    required this.program,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: program.isActive
                  ? AppColors.brandPrimaryLight
                  : AppColors.backgroundMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.thermostat_outlined,
              size: 18,
              color: program.isActive
                  ? AppColors.brandPrimary
                  : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.name, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${program.temperatureCelsius} °C · '
                  '${program.plateauMinutes} min'
                  '${program.isActive ? '' : ' · Inactif'}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 20, color: AppColors.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ]),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: AppColors.danger)),
                    ]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? value;
  const _Field({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(
            value ?? '—',
            style: AppTypography.bodyStrong.copyWith(
              color: value == null
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
