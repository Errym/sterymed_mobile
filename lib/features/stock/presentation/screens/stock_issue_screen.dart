import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../cubit/stock_action_cubit.dart';

class StockIssueScreen extends StatelessWidget {
  const StockIssueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StockActionCubit>(),
      child: const _StockIssueForm(),
    );
  }
}

class _StockIssueForm extends StatefulWidget {
  const _StockIssueForm();

  @override
  State<_StockIssueForm> createState() => _StockIssueFormState();
}

class _StockIssueFormState extends State<_StockIssueForm> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _batchCtrl.dispose();
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<StockActionCubit>().issue(
          batchId: _batchCtrl.text.trim(),
          locationId: _locationCtrl.text.trim(),
          qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
          reason: _reasonCtrl.text.trim().isEmpty
              ? null
              : _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(context, 'Sortie enregistrée.',
          kind: SnackKind.success);
      context.pop();
    } else {
      AppSnackbar.show(context, 'Échec de l\'enregistrement.',
          kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Sortie de stock'),
      body: BlocBuilder<StockActionCubit, StockActionState>(
        builder: (context, state) {
          final isSubmitting = state.status == StockActionStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppTextField(
                  label: 'Identifiant du lot *',
                  hint: 'ex. UUID du lot',
                  controller: _batchCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Identifiant de l\'emplacement *',
                  hint: 'ex. UUID du local',
                  controller: _locationCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Quantité *',
                  hint: 'ex. 2',
                  keyboardType: TextInputType.number,
                  controller: _qtyCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis.';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) {
                      return 'Entrez un nombre positif.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextArea(
                  label: 'Motif (optionnel)',
                  controller: _reasonCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Enregistrer la sortie',
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
