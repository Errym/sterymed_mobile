import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/product_data.dart';
import '../../data/repositories/product_repository.dart';
import '../bloc/product_list_bloc.dart';

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, this.existing});

  final ProductData? existing;

  static Future<bool?> show(BuildContext context, {ProductData? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<ProductListBloc>(),
        child: ProductFormSheet(existing: existing),
      ),
    );
  }

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController _barcodeCtrl;
  bool _isSterilizable = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _refCtrl = TextEditingController(text: widget.existing?.reference ?? '');
    _unitCtrl = TextEditingController(text: widget.existing?.unit ?? 'u');
    _thresholdCtrl = TextEditingController(
      text: widget.existing?.minThreshold.toString() ?? '5',
    );
    _barcodeCtrl = TextEditingController(text: widget.existing?.barcode ?? '');
    _isSterilizable = widget.existing?.isSterilizable ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _refCtrl.dispose();
    _unitCtrl.dispose();
    _thresholdCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final req = ProductCreateRequest(
      name: _nameCtrl.text.trim(),
      reference: _refCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      minThreshold: int.tryParse(_thresholdCtrl.text.trim()) ?? 0,
      isSterilizable: _isSterilizable,
      barcode:
          _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
    );
    final bloc = context.read<ProductListBloc>();
    setState(() => _submitting = true);
    try {
      final existing = widget.existing;
      if (existing != null) {
        await getIt<ProductRepository>().update(existing.id, req);
      } else {
        await getIt<ProductRepository>().create(req);
      }
      if (!mounted) return;
      bloc.add(const LoadProducts());
      AppSnackbar.show(context, 'Produit enregistré.', kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
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
              widget.existing == null ? 'Nouveau produit' : 'Modifier produit',
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
              label: 'Référence *',
              controller: _refCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Unité', controller: _unitCtrl),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Seuil minimum',
              controller: _thresholdCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Code-barres', controller: _barcodeCtrl),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _isSterilizable,
              onChanged: (v) => setState(() => _isSterilizable = v),
              title: const Text('Stérilisable', style: AppTypography.body),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Enregistrer le produit',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
