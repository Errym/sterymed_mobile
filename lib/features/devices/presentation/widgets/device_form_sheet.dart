import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../cycles/data/repositories/device_repository.dart';
import '../../../sites/data/models/site_data.dart';
import '../../../sites/data/repositories/site_repository.dart';

class DeviceFormSheet extends StatefulWidget {
  const DeviceFormSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const DeviceFormSheet(),
    );
  }

  @override
  State<DeviceFormSheet> createState() => _DeviceFormSheetState();
}

class _DeviceFormSheetState extends State<DeviceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<SiteData> _sites = [];
  String? _siteId;
  String _kind = 'autoclave';
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      // Force fresh — never trust a possibly-empty cache.
      final sites = await getIt<SiteRepository>().list(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _siteId = sites.isNotEmpty ? sites.first.id : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_siteId == null) {
      AppSnackbar.show(context, 'Créez d\'abord un site.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      await getIt<DeviceRepository>().create(
        siteId: _siteId!,
        name: _nameCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim(),
        kind: _kind,
        manufacturer: _manufacturerCtrl.text.trim().isEmpty
            ? null
            : _manufacturerCtrl.text.trim(),
        model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Appareil enregistré.',
          kind: SnackKind.success);
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
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text('Nouvel appareil',
                      style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.md),
                  if (_sites.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Text(
                        'Aucun site disponible. Créez d\'abord un site dans '
                        'Sites & Espaces.',
                        style: AppTypography.caption,
                      ),
                    )
                  else
                    AppDropdown<String>(
                      label: 'Site *',
                      value: _siteId,
                      options: _sites
                          .map((s) =>
                              AppDropdownOption(value: s.id, label: s.name))
                          .toList(),
                      onChanged: (v) => setState(() => _siteId = v),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Nom *',
                    hint: 'Melag Vacuklav 40B+',
                    controller: _nameCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'N° de série *',
                    hint: 'MEL-001',
                    controller: _serialCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDropdown<String>(
                    label: 'Type',
                    value: _kind,
                    options: const [
                      AppDropdownOption(
                          value: 'autoclave', label: 'Autoclave'),
                      AppDropdownOption(
                          value: 'washer_disinfector',
                          label: 'Laveur désinfecteur'),
                      AppDropdownOption(
                          value: 'sealer', label: 'Thermoscelleuse'),
                      AppDropdownOption(value: 'other', label: 'Autre'),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? 'autoclave'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                      label: 'Fabricant',
                      hint: 'Melag',
                      controller: _manufacturerCtrl),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                      label: 'Modèle',
                      hint: 'Vacuklav 40B+',
                      controller: _modelCtrl),
                  const SizedBox(height: AppSpacing.md),
                  AppTextArea(
                      label: 'Notes', controller: _notesCtrl, maxLines: 2),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Enregistrer l\'appareil',
                    isLoading: _submitting,
                    onPressed: _sites.isEmpty ? null : _submit,
                  ),
                ],
              ),
            ),
    );
  }
}
