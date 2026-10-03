import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../data/models/laboratory_data.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../utils/laboratory_stats.dart';
import '../widgets/prosthetic_case_tile.dart';

part 'prosthetic_laboratories_screen_parts/laboratory_card.dart';
part 'prosthetic_laboratories_screen_parts/laboratory_sheet.dart';
part 'prosthetic_laboratories_screen_parts/laboratory_form.dart';

/// The partner laboratories: who they are, how to reach them, and how much of
/// the practice's work each one holds right now.
class ProstheticLaboratoriesScreen extends StatefulWidget {
  const ProstheticLaboratoriesScreen({super.key});

  @override
  State<ProstheticLaboratoriesScreen> createState() =>
      _ProstheticLaboratoriesScreenState();
}

class _ProstheticLaboratoriesScreenState
    extends State<ProstheticLaboratoriesScreen> {
  List<LaboratoryData> _labs = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  // One count request per laboratory, made when its card first appears and
  // kept for the life of the screen (scrolling must not re-ask the server).
  final Map<String, Future<LaboratoryStats>> _stats = {};

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
      final labs = await getIt<ProstheticRepository>()
          .listLaboratories(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _stats.clear();
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

  Future<LaboratoryStats> _statsFor(String id) => _stats.putIfAbsent(
        id,
        () => loadLaboratoryStats(getIt<ProstheticRepository>(), id),
      );

  List<LaboratoryData> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _labs;
    return _labs
        .where((l) => [l.name, l.contactName, l.contactPhone, l.contactEmail]
            .whereType<String>()
            .any((v) => v.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _createOrEdit({LaboratoryData? existing}) async {
    final ok = await showAppSheet<bool>(
      context,
      builder: (_) => _LaboratoryFormSheet(existing: existing),
    );
    if (ok == true) await _load();
  }

  Future<void> _archive(LaboratoryData lab) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Archiver ce laboratoire ?',
      message: '${lab.name}\n\nIl n\'apparaîtra plus dans la création de '
          'nouveaux dossiers. Les dossiers existants le gardent.',
      confirmLabel: 'Archiver',
      isDestructive: true,
    );
    if (!ok) return;
    try {
      await getIt<ProstheticRepository>()
          .updateLaboratory(lab.id, {'archived': true});
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _open(LaboratoryData lab) async {
    final action = await showAppSheet<_LabAction>(
      context,
      builder: (_) => _LaboratorySheet(
        lab: lab,
        stats: _statsFor(lab.id),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _LabAction.edit:
        await _createOrEdit(existing: lab);
      case _LabAction.archive:
        await _archive(lab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Laboratoires',
        actions: [
          IconButton(
            tooltip: 'Nouveau laboratoire',
            icon: const Icon(Icons.add),
            onPressed: () => _createOrEdit(),
          ),
        ],
      ),
      body: _loading && _labs.isEmpty
          ? const LoadingView()
          : _error != null && _labs.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : _labs.isEmpty
                  ? EmptyView(
                      title: 'Aucun laboratoire',
                      message: 'Ajoutez votre premier laboratoire partenaire.',
                      icon: Icons.local_shipping_outlined,
                      action: FilledButton.icon(
                        onPressed: () => _createOrEdit(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter un laboratoire'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          AppSearchField(
                            hint: 'Rechercher un laboratoire…',
                            onChanged: (v) => setState(() => _query = v),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              _query.trim().isEmpty
                                  ? '${_labs.length} laboratoire'
                                      '${_labs.length > 1 ? 's' : ''} partenaire'
                                      '${_labs.length > 1 ? 's' : ''}'
                                  : '${visible.length} résultat'
                                      '${visible.length > 1 ? 's' : ''}',
                              key: const Key('lab-count'),
                              style: AppTypography.eyebrow,
                            ),
                          ),
                          if (visible.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: Center(
                                child: Text(
                                  'Aucun laboratoire ne correspond.',
                                  style: AppTypography.caption,
                                ),
                              ),
                            ),
                          for (final lab in visible) ...[
                            _LabCard(
                              lab: lab,
                              stats: _statsFor(lab.id),
                              onTap: () => _open(lab),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
