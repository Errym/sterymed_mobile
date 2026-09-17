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

class StockAdjustScreen extends StatelessWidget {
  const StockAdjustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StockActionCubit>(),
      child: const _StockAdjustForm(),
    );
  }
}

class _StockAdjustForm extends StatefulWidget {
  const _StockAdjustForm();

  @override
  State<_StockAdjustForm> createState() => _StockAdjustFormState();
}

class _StockAdjustFormState extends State<_StockAdjustForm> {
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
    final ok = await context.read<StockActionCubit>().adjust(
          batchId: _batchCtrl.text.trim(),
          locationId: _locationCtrl.text.trim(),
          qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
          reason: _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(context, 'Ajustement enregistré.',
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
      appBar: const AppAppBar(title: 'Ajustement de stock'),
      body: BlocBuilder<StockActionCubit, StockActionState>(
        builder: (context, state) {
          final isSubmitting = state.status == StockActionStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Un ajustement corrige un écart d\'inventaire. '
                          'Le motif est obligatoire.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                  label: 'Quantité (négatif pour retirer) *',
                  hint: 'ex. 5 ou -3',
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  controller: _qtyCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis.';
                    if (int.tryParse(v.trim()) == null) {
                      return 'Entrez un nombre valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextArea(
                  label: 'Motif (obligatoire) *',
                  controller: _reasonCtrl,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Le motif est obligatoire pour un ajustement.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Enregistrer l\'ajustement',
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
