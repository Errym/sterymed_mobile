import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/maintenance_record_data.dart';
import '../../data/repositories/maintenance_record_repository.dart';
import 'device_maintenance_row.dart';
import 'maintenance_record_form_sheet.dart';

/// Append-only against the real backend (GET/POST /devices/{id}/
/// maintenance-records — no PATCH/DELETE route exists), so unlike
/// [DeviceProgrammesSection] there's no edit/delete here.
class DeviceMaintenanceSection extends StatefulWidget {
  final String deviceId;
  final bool canManage;
  const DeviceMaintenanceSection({
    super.key,
    required this.deviceId,
    required this.canManage,
  });

  @override
  State<DeviceMaintenanceSection> createState() =>
      _DeviceMaintenanceSectionState();
}

class _DeviceMaintenanceSectionState extends State<DeviceMaintenanceSection> {
  List<MaintenanceRecordData> _records = [];
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
      final records = await getIt<MaintenanceRecordRepository>()
          .list(widget.deviceId, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _records = records;
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
    final ok = await MaintenanceRecordFormSheet.show(
      context,
      deviceId: widget.deviceId,
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Maintenance (${_records.length})',
          trailing: widget.canManage
              ? IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Enregistrer une intervention',
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
        else if (_records.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Text(
              'Aucune intervention enregistrée.',
              style: AppTypography.caption,
            ),
          )
        else
          ..._records.map((r) => DeviceMaintenanceRow(record: r)),
      ],
    );
  }
}
