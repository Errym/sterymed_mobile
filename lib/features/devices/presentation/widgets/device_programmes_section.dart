import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../cycles/data/models/device_program_data.dart';
import '../../../cycles/data/repositories/device_program_repository.dart';
import 'device_programme_row.dart';
import 'programme_form_sheet.dart';

class DeviceProgrammesSection extends StatefulWidget {
  final String deviceId;
  final bool canManage;
  const DeviceProgrammesSection({
    super.key,
    required this.deviceId,
    required this.canManage,
  });

  @override
  State<DeviceProgrammesSection> createState() =>
      _DeviceProgrammesSectionState();
}

class _DeviceProgrammesSectionState extends State<DeviceProgrammesSection> {
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
        _error = ErrorMessage.from(e);
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
      AppSnackbar.show(context, 'Programme supprimé.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
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
          ..._programs.map((p) => DeviceProgrammeRow(
                program: p,
                onEdit: widget.canManage ? () => _edit(p) : null,
                onDelete: widget.canManage ? () => _delete(p) : null,
              )),
      ],
    );
  }
}
