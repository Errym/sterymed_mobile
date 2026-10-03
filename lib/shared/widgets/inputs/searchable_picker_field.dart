import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import 'app_search_field.dart';

/// One choice in a [SearchablePickerField].
class PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  const PickerOption({required this.id, required this.label, this.subtitle});
}

/// A field that opens a searchable list in a bottom sheet. Used where the list
/// can be long enough that scrolling a dropdown is slower than typing a few
/// letters (practitioners, laboratories — brief §6: "searchable dropdowns").
///
/// Matching ignores case and accents, so "bruno" finds "Brüno" and "ecole"
/// finds "École".
class SearchablePickerField extends StatelessWidget {
  final String label;
  final String? hint;

  /// The currently chosen option's id, if any.
  final String? value;
  final List<PickerOption> options;

  /// When set, the sheet starts with a row of this label that clears the
  /// choice (e.g. "Aucun laboratoire"). Without it a value is mandatory.
  final String? clearLabel;
  final ValueChanged<String?> onChanged;
  final String? errorText;
  final bool enabled;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.clearLabel,
    this.errorText,
    this.enabled = true,
  });

  PickerOption? get _selected {
    for (final o in options) {
      if (o.id == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _PickerSheet(
        title: label,
        options: options,
        selectedId: value,
        clearLabel: clearLabel,
      ),
    );
    if (result != null) onChanged(result.id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: enabled ? () => _open(context) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: hasError ? AppColors.danger : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? hint ?? 'Sélectionner',
                    style: selected == null
                        ? AppTypography.body
                            .copyWith(color: AppColors.textTertiary)
                        : AppTypography.bodyStrong,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search, size: 20),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Wraps the chosen id so "cleared" (null id) is distinguishable from "sheet
/// dismissed without choosing" (no result at all).
class _PickerResult {
  final String? id;
  const _PickerResult(this.id);
}

/// Lower-cases and strips the common French accents for matching.
String foldForSearch(String input) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<PickerOption> options;
  final String? selectedId;
  final String? clearLabel;

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selectedId,
    required this.clearLabel,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  List<PickerOption> get _filtered {
    final q = foldForSearch(_query.trim());
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) =>
            foldForSearch(o.label).contains(q) ||
            foldForSearch(o.subtitle ?? '').contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              hint: 'Rechercher...',
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                children: [
                  if (widget.clearLabel != null && _query.trim().isEmpty)
                    ListTile(
                      key: const Key('picker-clear'),
                      leading: const Icon(Icons.block_outlined),
                      title: Text(widget.clearLabel!),
                      onTap: () =>
                          Navigator.of(context).pop(const _PickerResult(null)),
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: Text('Aucun résultat.')),
                    ),
                  for (final o in items)
                    ListTile(
                      key: Key('picker-option-${o.id}'),
                      title: Text(o.label),
                      subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                      trailing: o.id == widget.selectedId
                          ? const Icon(Icons.check, color: AppColors.brandPrimary)
                          : null,
                      onTap: () =>
                          Navigator.of(context).pop(_PickerResult(o.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
