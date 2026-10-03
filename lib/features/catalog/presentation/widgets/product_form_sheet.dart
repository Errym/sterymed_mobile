import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
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

  /// Opened from the catalogue (which has a [ProductListBloc] to refresh) or
  /// from anywhere else, where the caller refreshes from the result.
  static Future<bool?> show(BuildContext context, {ProductData? existing}) {
    final bloc = _listBloc(context);
    return showAppSheet<bool>(
      context,
      builder: (_) => bloc == null
          ? ProductFormSheet(existing: existing)
          : BlocProvider.value(
              value: bloc,
              child: ProductFormSheet(existing: existing),
            ),
    );
  }

  static ProductListBloc? _listBloc(BuildContext context) {
    try {
      return BlocProvider.of<ProductListBloc>(context, listen: false);
    } catch (_) {
      return null;
    }
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
  bool _optionsFailed = false;

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

  /// Adds a family without leaving the product form (families are otherwise
  /// only creatable on the web, which left a new clinic with an empty list).
  Future<void> _createCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewFamilyDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final created = await getIt<ProductCategoryRepository>().create(name);
      if (!mounted) return;
      setState(() {
        if (!_categories.any((c) => c.id == created.id)) {
          _categories = [..._categories, created];
        }
        _categoryId = created.id;
      });
      AppSnackbar.show(context, 'Famille créée.', kind: SnackKind.success);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
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
      // Both fields are optional, so a failed lookup does not block the form.
      // The record's current choices stay selected (see AppDropdown), and the
      // user is told the lists could not be loaded rather than seeing them
      // silently empty.
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _optionsFailed = true;
      });
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
      unit: _unitCtrl.text.trim().isEmpty ? 'u' : _unitCtrl.text.trim(),
      minThreshold: int.parse(_thresholdCtrl.text.trim()),
      isSterilizable: _isSterilizable,
      barcode:
          _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      categoryId: _categoryId,
      defaultLocationId: _locationId,
    );
    final bloc = ProductFormSheet._listBloc(context);
    setState(() => _submitting = true);
    try {
      final existing = widget.existing;
      if (existing != null) {
        await getIt<ProductRepository>().update(existing.id, req);
      } else {
        await getIt<ProductRepository>().create(req);
      }
      if (!mounted) return;
      bloc?.add(const LoadProducts());
      AppSnackbar.show(context, 'Produit enregistré.', kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The product as it will look in the catalogue, updated as the person
  /// types, so a mistake is visible before saving.
  Widget _preview() {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [_nameCtrl, _refCtrl, _unitCtrl, _thresholdCtrl, _barcodeCtrl],
      ),
      builder: (context, _) {
        final name = _nameCtrl.text.trim();
        final ref = _refCtrl.text.trim();
        final code = _barcodeCtrl.text.trim();
        final unit = _unitCtrl.text.trim().isEmpty ? 'u' : _unitCtrl.text.trim();
        final threshold = int.tryParse(_thresholdCtrl.text.trim());
        String? family;
        for (final c in _categories) {
          if (c.id == _categoryId) family = c.name;
        }
        final eyebrow = [
          if (ref.isNotEmpty) ref,
          if (code.isNotEmpty) code,
        ].join('  ·  ');
        return Container(
          key: const Key('product-preview'),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  _isSterilizable
                      ? Icons.sanitizer_outlined
                      : Icons.inventory_2_outlined,
                  color: AppColors.navyHeader,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.isEmpty ? 'RÉFÉRENCE' : eyebrow,
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.isEmpty ? 'Nom du produit' : name,
                      style: AppTypography.cardTitle.copyWith(
                        color: name.isEmpty ? AppColors.textTertiary : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _PreviewTag('Unité : $unit'),
                        if (threshold != null && threshold > 0)
                          _PreviewTag('Seuil $threshold $unit'),
                        if (family != null) _PreviewTag(family),
                        if (_isSterilizable)
                          const _PreviewTag('Stérilisable',
                              color: AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderMedium,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    editing ? 'Modifier produit' : 'Nouveau produit',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    editing
                        ? 'Les changements s\'appliquent à tout le cabinet.'
                        : 'Un produit du catalogue peut ensuite être commandé, '
                            'réceptionné et suivi lot par lot.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _preview(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Identité',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'Nom *',
                        controller: _nameCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                      AppTextField(
                        label: 'Référence *',
                        controller: _refCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                      AppTextField(
                        label: 'Code-barres',
                        controller: _barcodeCtrl,
                        hint: 'Scannable depuis la recherche du stock',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Stock',
                    children: [
                      AppTextField(label: 'Unité', controller: _unitCtrl),
                      AppTextField(
                        label: 'Seuil minimum',
                        controller: _thresholdCtrl,
                        keyboardType: TextInputType.number,
                        hint: 'En dessous, le produit passe en « stock bas »',
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return 'Requis.';
                          final n = int.tryParse(text);
                          if (n == null || n < 0) {
                            return 'Entrez un nombre entier positif.';
                          }
                          return null;
                        },
                      ),
                      SwitchListTile(
                        value: _isSterilizable,
                        onChanged: (v) => setState(() => _isSterilizable = v),
                        title:
                            const Text('Stérilisable', style: AppTypography.body),
                        subtitle: const Text(
                          'Peut être chargé dans un cycle d\'autoclave',
                          style: AppTypography.caption,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Classement',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      if (_optionsFailed)
                        Text(
                          'Les listes (familles, emplacements) n\'ont pas pu '
                          'être chargées. Les valeurs actuelles sont conservées.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.warning),
                        ),
                      AppDropdown<String?>(
                        label: 'Famille',
                        value: _categoryId,
                        enabled: !_loadingOptions,
                        options: [
                          const AppDropdownOption(value: null, label: 'Aucune'),
                          ..._categories.map(
                            (c) => AppDropdownOption(value: c.id, label: c.name),
                          ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _loadingOptions ? null : _createCategory,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nouvelle famille'),
                        ),
                      ),
                      AppDropdown<String?>(
                        label: 'Emplacement par défaut',
                        value: _locationId,
                        enabled: !_loadingOptions,
                        options: [
                          const AppDropdownOption(value: null, label: 'Aucun'),
                          ..._locations.map(
                            (l) => AppDropdownOption(value: l.id, label: l.label),
                          ),
                        ],
                        onChanged: (v) => setState(() => _locationId = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PinnedFooter(
              child: PrimaryButton(
                label: 'Enregistrer le produit',
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  final String text;
  final Color? color;
  const _PreviewTag(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color ?? AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}


/// Owns its controller so it is disposed only once the dialog is fully gone
/// (disposing it right after `showDialog` returns races the exit animation).
class _NewFamilyDialog extends StatefulWidget {
  const _NewFamilyDialog();

  @override
  State<_NewFamilyDialog> createState() => _NewFamilyDialogState();
}

class _NewFamilyDialogState extends State<_NewFamilyDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle famille'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nom de la famille'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
