import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/laboratory_data.dart';
import '../../data/repositories/prosthetic_repository.dart';

class ProstheticLaboratoriesScreen extends StatefulWidget {
  const ProstheticLaboratoriesScreen({super.key});

  @override
  State<ProstheticLaboratoriesScreen> createState() =>
      _ProstheticLaboratoriesScreenState();
}

class _ProstheticLaboratoriesScreenState
    extends State<ProstheticLaboratoriesScreen> {
  List<LaboratoryData> _labs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final labs = await getIt<ProstheticRepository>()
          .listLaboratories(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  Future<void> _createOrEdit({LaboratoryData? existing}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _LaboratoryFormSheet(existing: existing),
    );
    if (ok == true) await _load();
  }

  Future<void> _archive(LaboratoryData lab) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Archiver ce laboratoire ?',
      message: '${lab.name}\n\nIl n\'apparaîtra plus dans la création de '
          'nouveaux dossiers.',
      confirmLabel: 'Archiver',
      isDestructive: true,
    );
    if (!ok) return;
    try {
      await getIt<ProstheticRepository>()
          .updateLaboratory(lab.id, {'archived': true});
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Laboratoires',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createOrEdit(),
          ),
        ],
      ),
      body: _loading && _labs.isEmpty
          ? const LoadingView()
          : _error != null && _labs.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : _labs.isEmpty
                  ? EmptyView(
                      title: 'Aucun laboratoire',
                      message: 'Ajoutez votre premier laboratoire partenaire.',
                      icon: Icons.local_shipping_outlined,
                      action: FilledButton.icon(
                        onPressed: () => _createOrEdit(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter un laboratoire'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _labs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final lab = _labs[index];
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: lab.archived
                                ? AppColors.backgroundApp
                                : AppColors.backgroundCard,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lab.name,
                                        style: AppTypography.bodyStrong),
                                    if (lab.contactName != null)
                                      Text(lab.contactName!,
                                          style: AppTypography.caption),
                                    if (lab.contactPhone != null)
                                      Text(lab.contactPhone!,
                                          style: AppTypography.caption),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit'
                                    ? _createOrEdit(existing: lab)
                                    : _archive(lab),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('Modifier')),
                                  if (!lab.archived)
                                    const PopupMenuItem(
                                        value: 'archive',
                                        child: Text('Archiver')),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _LaboratoryFormSheet extends StatefulWidget {
  final LaboratoryData? existing;
  const _LaboratoryFormSheet({this.existing});

  @override
  State<_LaboratoryFormSheet> createState() => _LaboratoryFormSheetState();
}

class _LaboratoryFormSheetState extends State<_LaboratoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _contactNameCtrl =
      TextEditingController(text: widget.existing?.contactName);
  late final _contactPhoneCtrl =
      TextEditingController(text: widget.existing?.contactPhone);
  late final _contactEmailCtrl =
      TextEditingController(text: widget.existing?.contactEmail);
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'contact_name': _contactNameCtrl.text.trim(),
      'contact_phone': _contactPhoneCtrl.text.trim(),
      'contact_email': _contactEmailCtrl.text.trim(),
    };
    try {
      final repo = getIt<ProstheticRepository>();
      if (widget.existing != null) {
        await repo.updateLaboratory(widget.existing!.id, data);
      } else {
        await repo.createLaboratory(data);
      }
      if (!mounted) return;
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
              widget.existing != null
                  ? 'Modifier le laboratoire'
                  : 'Nouveau laboratoire',
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
            AppTextField(label: 'Contact', controller: _contactNameCtrl),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Téléphone', controller: _contactPhoneCtrl),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'E-mail', controller: _contactEmailCtrl),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Enregistrer',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
