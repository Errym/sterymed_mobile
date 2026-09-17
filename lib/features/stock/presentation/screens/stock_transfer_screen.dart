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

class StockTransferScreen extends StatelessWidget {
  const StockTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StockActionCubit>(),
      child: const _StockTransferForm(),
    );
  }
}

class _StockTransferForm extends StatefulWidget {
  const _StockTransferForm();

  @override
  State<_StockTransferForm> createState() => _StockTransferFormState();
}

class _StockTransferFormState extends State<_StockTransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _batchCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<StockActionCubit>().transfer(
          batchId: _batchCtrl.text.trim(),
          fromLocationId: _fromCtrl.text.trim(),
          toLocationId: _toCtrl.text.trim(),
          qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
          reason: _reasonCtrl.text.trim().isEmpty
              ? null
              : _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(context, 'Transfert enregistré.',
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
      appBar: const AppAppBar(title: 'Transfert de stock'),
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
                  label: 'Depuis l\'emplacement *',
                  hint: 'ex. UUID source',
                  controller: _fromCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Vers l\'emplacement *',
                  hint: 'ex. UUID destination',
                  controller: _toCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Quantité *',
                  hint: 'ex. 3',
                  keyboardType: TextInputType.number,
                  controller: _qtyCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis.';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Entrez un nombre positif.';
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
                  label: 'Enregistrer le transfert',
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
