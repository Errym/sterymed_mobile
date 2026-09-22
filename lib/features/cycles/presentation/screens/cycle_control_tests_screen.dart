import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/control_test_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../widgets/control_test_row.dart';

class CycleControlTestsScreen extends StatefulWidget {
  final String cycleId;
  const CycleControlTestsScreen({super.key, required this.cycleId});

  @override
  State<CycleControlTestsScreen> createState() =>
      _CycleControlTestsScreenState();
}

class _CycleControlTestsScreenState extends State<CycleControlTestsScreen> {
  List<ControlTestData> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tests = await context
          .read<CycleRepository>()
          .listControlTests(widget.cycleId);
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    var type = ControlTestType.vacuum;
    var result = ControlTestResult.pass;
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enregistrer un contrôle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdown<ControlTestType>(
                  label: 'Type',
                  value: type,
                  options: ControlTestType.values
                      .map((t) => AppDropdownOption(value: t, label: t.label))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdown<ControlTestResult>(
                  label: 'Résultat',
                  value: result,
                  options: ControlTestResult.values
                      .map((r) => AppDropdownOption(value: r, label: r.label))
                      .toList(),
                  onChanged: (v) => setDialogState(() => result = v ?? result),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextArea(label: 'Notes', controller: notesCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<CycleRepository>().addControlTest(widget.cycleId, {
        'type': _typeToString(type),
        'result': result == ControlTestResult.pass ? 'pass' : 'fail',
        'performed_at': DateTime.now().toIso8601String(),
        if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.show(context, 'Contrôle enregistré.',
          kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  String _typeToString(ControlTestType t) {
    switch (t) {
      case ControlTestType.vacuum:
        return 'vacuum';
      case ControlTestType.bowieDick:
        return 'bowie_dick';
      case ControlTestType.helix:
        return 'helix';
      case ControlTestType.biological:
        return 'biological';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Contrôles'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tests.isEmpty
              ? const EmptyView(
                  title: 'Aucun contrôle',
                  message: 'Enregistrez les contrôles de stérilisation.',
                  icon: Icons.science_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      for (var i = 0; i < _tests.length; i++)
                        AnimatedListItem(
                          index: i,
                          child: ControlTestRow(test: _tests[i]),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
