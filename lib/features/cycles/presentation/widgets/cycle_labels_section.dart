import 'package:flutter/material.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../dlu/data/models/dlu_rule_data.dart';
import '../../../dlu/data/repositories/dlu_repository.dart';
import '../../data/repositories/cycle_repository.dart';
import 'cycle_info_banner.dart';

class CycleLabelsSection extends StatefulWidget {
  final String cycleId;
  const CycleLabelsSection({super.key, required this.cycleId});

  @override
  State<CycleLabelsSection> createState() => _CycleLabelsSectionState();
}

class _CycleLabelsSectionState extends State<CycleLabelsSection> {
  late Future<int> _countFuture;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _countFuture = getIt<CycleRepository>().countLabels(widget.cycleId);
  }

  void _reload() {
    setState(() {
      _countFuture = getIt<CycleRepository>().countLabels(widget.cycleId);
    });
  }

  Future<void> _generate() async {
    final rules = await getIt<DluRepository>().list();
    if (!mounted) return;
    if (rules.isEmpty) {
      AppSnackbar.show(
        context,
        'Aucune règle DLU configurée. Contactez le titulaire du cabinet.',
        kind: SnackKind.error,
      );
      return;
    }

    DluRuleData selected = rules.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Générer les étiquettes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Une étiquette sera créée pour chaque instrument de ce '
                  'cycle, avec la DLC calculée depuis la règle choisie.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdown<DluRuleData>(
                  label: 'Emballage / conditions de stockage',
                  value: selected,
                  options: rules
                      .map((r) => AppDropdownOption(
                            value: r,
                            label: '${r.packagingType} — '
                                '${r.storageCondition} '
                                '(${r.shelfLifeDays} j)',
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selected = v ?? selected),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _generating = true);
    try {
      final count = await getIt<CycleRepository>().generateLabels(
        widget.cycleId,
        packagingType: selected.packagingType,
        storageCondition: selected.storageCondition,
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        '$count étiquette(s) générée(s).',
        kind: SnackKind.success,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, _labelError(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _labelError(Object e) {
    if (e is ApiException) {
      switch (e.code) {
        case 'CYCLE_NOT_RELEASED':
          return 'Les étiquettes ne peuvent être générées que pour un '
              'cycle libéré.';
        case 'CYCLE_LABELS_ALREADY_GENERATED':
          return 'Les étiquettes de ce cycle ont déjà été générées.';
        case 'DLU_RULE_NOT_FOUND':
          return 'Aucune règle DLU ne correspond à cette combinaison '
              'emballage/stockage.';
      }
    }
    return ErrorMessage.from(e);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return CycleInfoBanner(message: _labelError(snap.error!));
        }
        final count = snap.data ?? 0;
        if (count > 0) {
          return CycleInfoBanner(
            message: '$count étiquette(s) générée(s) pour ce cycle.',
          );
        }
        return PrimaryButton(
          label: 'Générer les étiquettes',
          icon: Icons.qr_code_2_outlined,
          isLoading: _generating,
          onPressed: _generating ? null : _generate,
        );
      },
    );
  }
}
