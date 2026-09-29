import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../data/local/cycle_notes_cache.dart';

class CycleNotesSection extends StatefulWidget {
  final String cycleId;
  final String? initialNotes;

  const CycleNotesSection(
      {super.key, required this.cycleId, this.initialNotes});

  @override
  State<CycleNotesSection> createState() => _CycleNotesSectionState();
}

class _CycleNotesSectionState extends State<CycleNotesSection> {
  final _cache = CycleNotesCache();
  final _notesCtrl = TextEditingController();
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await _cache.get(widget.cycleId);
    if (!mounted) return;
    setState(() {
      _notesCtrl.text = cached ?? widget.initialNotes ?? '';
      _loading = false;
      _editing = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _cache.save(widget.cycleId, _notesCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    AppSnackbar.show(context, 'Notes enregistrées.', kind: SnackKind.success);
  }

  void _cancel() {
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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

    if (_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextArea(
            controller: _notesCtrl,
            hint:
                'Ex : Cassettes chirurgicales Dr. Watson, sachets turbines...',
            maxLines: 5,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : _cancel,
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Enregistrer',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final hasNotes = _notesCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasNotes ? _notesCtrl.text : 'Aucune note pour ce cycle.',
                  style: hasNotes ? AppTypography.body : AppTypography.caption,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.brandPrimary),
                tooltip: hasNotes ? 'Modifier' : 'Ajouter',
                onPressed: () => setState(() => _editing = true),
              ),
            ],
          ),
const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Ces notes sont stockées uniquement sur cet appareil '
                    'et ne sont pas synchronisées avec le serveur. '
                    'Elles seront perdues si l\'application est désinstallée.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
