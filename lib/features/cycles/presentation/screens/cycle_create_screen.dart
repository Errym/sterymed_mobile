import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/repositories/cycle_repository.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdCtrl = TextEditingController();
  final _programIdCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    _programIdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<CycleRepository>().create({
        'device_id': _deviceIdCtrl.text.trim(),
        if (_programIdCtrl.text.trim().isNotEmpty)
          'device_program_id': _programIdCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.show(context, 'Cycle créé.', kind: SnackKind.success);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Nouveau cycle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppTextField(
              label: 'Appareil (ID)',
              hint: 'Identifiant de l\'appareil',
              controller: _deviceIdCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Programme (ID, optionnel)',
              controller: _programIdCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              label: 'Notes (optionnel)',
              controller: _notesCtrl,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Créer le cycle',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
