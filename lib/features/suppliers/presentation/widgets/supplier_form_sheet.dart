import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../data/models/supplier_data.dart';
import '../../data/repositories/supplier_repository.dart';
import '../bloc/supplier_list_bloc.dart';
import '../../../../core/utils/error_message.dart';

class SupplierFormSheet extends StatefulWidget {
  final SupplierData? existing;
  const SupplierFormSheet({super.key, this.existing});

  /// Opened from the list (which has a [SupplierListBloc] to refresh) or from a
  /// supplier's own page (which has none and refreshes itself from the result).
  static Future<bool?> show(BuildContext context, {SupplierData? existing}) {
    final bloc = _listBloc(context);
    return showAppSheet<bool>(
      context,
      builder: (_) => bloc == null
          ? SupplierFormSheet(existing: existing)
          : BlocProvider.value(
              value: bloc,
              child: SupplierFormSheet(existing: existing),
            ),
    );
  }

  static SupplierListBloc? _listBloc(BuildContext context) {
    try {
      return BlocProvider.of<SupplierListBloc>(context, listen: false);
    } catch (_) {
      return null;
    }
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
      SupplierFormSheet._listBloc(context)?.add(const LoadSuppliers());
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

  /// The supplier as it will appear in the list, updated as the person types.
  Widget _preview() {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [_nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl],
      ),
      builder: (context, _) {
        final name = _nameCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();
        final email = _emailCtrl.text.trim();
        final address = _addressCtrl.text.trim();
        return PreviewCard(
          key: const Key('supplier-preview'),
          mark: EntityMark.initials(
            name.isEmpty ? '•' : EntityMark.initialsOf(name),
          ),
          eyebrow: address.isEmpty ? 'FOURNISSEUR' : address.toUpperCase(),
          title: name.isEmpty ? 'Nom du fournisseur' : name,
          titleIsPlaceholder: name.isEmpty,
          tags: [
            if (phone.isNotEmpty) InfoTag(phone, icon: Icons.call_outlined),
            if (email.isNotEmpty) InfoTag(email, icon: Icons.mail_outline),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const SheetHandle(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _isEdit ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isEdit
                        ? 'Les commandes déjà passées gardent ce fournisseur.'
                        : 'Une fois enregistré, vous pourrez lui lier des '
                            'produits et lui passer commande.',
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Contact',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'E-mail',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return null;
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(text)
                              ? null
                              : 'Adresse e-mail invalide.';
                        },
                      ),
                      AppTextField(
                        label: 'Téléphone',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Adresse',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'Adresse',
                        controller: _addressCtrl,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PinnedFooter(
              child: PrimaryButton(
                label: _isEdit
                    ? 'Enregistrer les modifications'
                    : 'Enregistrer le fournisseur',
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
