import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/supplier_data.dart';
import '../../data/repositories/supplier_repository.dart';
import '../bloc/supplier_list_bloc.dart';
import '../../../../core/utils/error_message.dart';

class SupplierFormSheet extends StatefulWidget {
  final SupplierData? existing;
  const SupplierFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {SupplierData? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<SupplierListBloc>(),
        child: SupplierFormSheet(existing: existing),
      ),
    );
  }

  @override
  State<SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repo = getIt<SupplierRepository>();
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
        );
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      context.read<SupplierListBloc>().add(const LoadSuppliers());
      AppSnackbar.show(context, 'Fournisseur enregistré.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _isEdit ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom *',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'E-mail',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Téléphone',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                label: 'Adresse', controller: _addressCtrl, maxLines: 2),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _isEdit
                  ? 'Enregistrer les modifications'
                  : 'Enregistrer le fournisseur',
              onPressed: _submit,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}
