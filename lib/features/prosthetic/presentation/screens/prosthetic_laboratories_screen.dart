import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
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
    final ok = await showAppSheet<bool>(
      context,
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
            tooltip: 'Nouveau laboratoire',
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
                        return _LabCard(
                          lab: lab,
                          onEdit: () => _createOrEdit(existing: lab),
                          onArchive: () => _archive(lab),
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

  bool _validEmail(String text) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
                    isEdit ? 'Modifier le laboratoire' : 'Nouveau laboratoire',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Il sera proposé à la création d\'un dossier prothétique '
                    'et sert à suivre les travaux envoyés.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _nameCtrl,
                      _contactNameCtrl,
                      _contactPhoneCtrl,
                      _contactEmailCtrl,
                    ]),
                    builder: (context, _) {
                      final name = _nameCtrl.text.trim();
                      final person = _contactNameCtrl.text.trim();
                      return PreviewCard(
                        key: const Key('lab-preview'),
                        mark: EntityMark.initials(EntityMark.initialsOf(name)),
                        eyebrow: 'LABORATOIRE PARTENAIRE',
                        title: name.isEmpty ? 'Nom du laboratoire' : name,
                        titleIsPlaceholder: name.isEmpty,
                        tags: [
                          if (person.isNotEmpty)
                            InfoTag(person, icon: Icons.person_outline),
                          if (_contactPhoneCtrl.text.trim().isNotEmpty)
                            InfoTag(
                              _contactPhoneCtrl.text.trim(),
                              icon: Icons.call_outlined,
                            ),
                          if (_contactEmailCtrl.text.trim().isNotEmpty)
                            InfoTag(
                              _contactEmailCtrl.text.trim(),
                              icon: Icons.mail_outline,
                            ),
                        ],
                      );
                    },
                  ),
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
                        label: 'Contact',
                        hint: 'Prénom et nom du technicien',
                        controller: _contactNameCtrl,
                      ),
                      AppTextField(
                        label: 'Téléphone',
                        controller: _contactPhoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                      AppTextField(
                        label: 'E-mail',
                        controller: _contactEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return null;
                          return _validEmail(text)
                              ? null
                              : 'Adresse e-mail invalide.';
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PinnedFooter(
              child: PrimaryButton(
                label: isEdit ? 'Enregistrer' : 'Ajouter le laboratoire',
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

/// A partner laboratory: who it is, who to reach, one tap to call or write.
class _LabCard extends StatelessWidget {
  final LaboratoryData lab;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  const _LabCard({
    required this.lab,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('lab-${lab.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityMark.initials(EntityMark.initialsOf(lab.name)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lab.name, style: AppTypography.cardTitle),
                    if ((lab.contactName ?? '').isNotEmpty)
                      Text(lab.contactName!, style: AppTypography.caption),
                  ],
                ),
              ),
              if (lab.archived)
                const InfoTag('Archivé', icon: Icons.inventory_2_outlined),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit() : onArchive(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  if (!lab.archived)
                    const PopupMenuItem(
                        value: 'archive', child: Text('Archiver')),
                ],
              ),
            ],
          ),
          if ((lab.contactPhone ?? '').isNotEmpty ||
              (lab.contactEmail ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ContactActions(phone: lab.contactPhone, email: lab.contactEmail),
          ],
        ],
      ),
    );
  }
}
