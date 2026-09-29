import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../stock/data/models/stock_option.dart';
import '../../../stock/data/repositories/stock_repository.dart';
import '../../data/models/product_category_data.dart';
import '../../data/models/product_data.dart';
import '../../data/repositories/product_category_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../bloc/product_list_bloc.dart';
import '../../../../core/utils/error_message.dart';

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

  String? _categoryId;
  String? _locationId;
  List<ProductCategoryData> _categories = [];
  List<StockOption> _locations = [];
  bool _loadingOptions = true;

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
    _categoryId = widget.existing?.categoryId;
    _locationId = widget.existing?.defaultLocationId;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        getIt<ProductCategoryRepository>().list(),
        getIt<StockRepository>().listOptions(),
      ]);
      final categories = results[0] as List<ProductCategoryData>;
      final options = results[1] as ({
        List<StockOption> batches,
        List<StockOption> locations
      });
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _locations = options.locations;
        _loadingOptions = false;
      });
    } catch (_) {
      // Both fields are optional server-side — a failed lookup just means
      // an empty dropdown, not a blocked form.
      if (!mounted) return;
      setState(() => _loadingOptions = false);
    }
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
      categoryId: _categoryId,
      defaultLocationId: _locationId,
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
            AppDropdown<String?>(
              label: 'Famille',
              value: _categoryId,
              enabled: !_loadingOptions,
              options: [
                const AppDropdownOption(value: null, label: 'Aucune'),
                ..._categories
                    .map((c) => AppDropdownOption(value: c.id, label: c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String?>(
              label: 'Emplacement par défaut',
              value: _locationId,
              enabled: !_loadingOptions,
              options: [
                const AppDropdownOption(value: null, label: 'Aucun'),
                ..._locations
                    .map((l) => AppDropdownOption(value: l.id, label: l.label)),
              ],
              onChanged: (v) => setState(() => _locationId = v),
            ),
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
