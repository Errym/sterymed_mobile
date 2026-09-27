import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';

class AuditFilterResult {
  final String? actorId;
  final String? actorLabel;
  final String? subjectType;
  final DateTime? from;
  final DateTime? to;

  const AuditFilterResult({
    this.actorId,
    this.actorLabel,
    this.subjectType,
    this.from,
    this.to,
  });
}

class AuditFilterSheet extends StatefulWidget {
  final List<MapEntry<String, String>> knownActors;
  final List<MapEntry<String, String>> knownSubjectTypes;
  final String? actorId;
  final String? subjectType;
  final DateTime? from;
  final DateTime? to;

  const AuditFilterSheet({
    super.key,
    required this.knownActors,
    required this.knownSubjectTypes,
    this.actorId,
    this.subjectType,
    this.from,
    this.to,
  });

  static Future<AuditFilterResult?> show(
    BuildContext context, {
    required List<MapEntry<String, String>> knownActors,
    required List<MapEntry<String, String>> knownSubjectTypes,
    String? actorId,
    String? subjectType,
    DateTime? from,
    DateTime? to,
  }) {
    return showModalBottomSheet<AuditFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuditFilterSheet(
        knownActors: knownActors,
        knownSubjectTypes: knownSubjectTypes,
        actorId: actorId,
        subjectType: subjectType,
        from: from,
        to: to,
      ),
    );
  }

  @override
  State<AuditFilterSheet> createState() => _AuditFilterSheetState();
}

class _AuditFilterSheetState extends State<AuditFilterSheet> {
  String? _actorId;
  String? _subjectType;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _actorId = widget.actorId;
    _subjectType = widget.subjectType;
    _from = widget.from;
    _to = widget.to;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtres avancés', style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String?>(
            label: 'Auteur',
            hint: 'Tous les auteurs',
            value: _actorId,
            options: [
              const AppDropdownOption(value: null, label: 'Tous les auteurs'),
              ...widget.knownActors.map(
                (e) => AppDropdownOption(value: e.key, label: e.value),
              ),
            ],
            onChanged: (v) => setState(() => _actorId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String?>(
            label: 'Type d\'élément',
            hint: 'Tous les types',
            value: _subjectType,
            options: [
              const AppDropdownOption(value: null, label: 'Tous les types'),
              ...widget.knownSubjectTypes.map(
                (e) => AppDropdownOption(value: e.key, label: e.value),
              ),
            ],
            onChanged: (v) => setState(() => _subjectType = v),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppDatePicker(
                  label: 'Du',
                  value: _from,
                  lastDate: _to,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppDatePicker(
                  label: 'Au',
                  value: _to,
                  firstDate: _from,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Réinitialiser',
                  onPressed: () => setState(() {
                    _actorId = null;
                    _subjectType = null;
                    _from = null;
                    _to = null;
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  label: 'Appliquer',
                  onPressed: () {
                    final actorLabel = _actorId == null
                        ? null
                        : widget.knownActors
                            .firstWhere((e) => e.key == _actorId)
                            .value;
                    Navigator.of(context).pop(
                      AuditFilterResult(
                        actorId: _actorId,
                        actorLabel: actorLabel,
                        subjectType: _subjectType,
                        from: _from,
                        to: _to,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
