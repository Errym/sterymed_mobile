part of '../prosthetic_laboratories_screen.dart';

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
  late final _addressCtrl = TextEditingController(text: widget.existing?.address);
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes);
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
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
      'address': _addressCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
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
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Adresse et remarques',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppTextArea(
                        label: 'Adresse',
                        controller: _addressCtrl,
                        maxLines: 2,
                      ),
                      AppTextArea(
                        label: 'Remarques',
                        hint: 'Délais habituels, jours de livraison, consignes…',
                        controller: _notesCtrl,
                        maxLines: 3,
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
