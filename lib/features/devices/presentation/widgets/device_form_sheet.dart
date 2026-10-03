import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../cycles/data/repositories/device_repository.dart';
import '../../../sites/data/models/site_data.dart';
import '../../../sites/data/repositories/site_repository.dart';
import '../../data/repositories/device_detail_repository.dart';
import '../../../../core/utils/error_message.dart';

class DeviceFormSheet extends StatefulWidget {
  final String? existingId;

  const DeviceFormSheet({super.key, this.existingId});

  static Future<bool?> show(BuildContext context, {String? existingId}) {
    return showAppSheet<bool>(
      context,
      builder: (_) => DeviceFormSheet(existingId: existingId),
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
  String _status = 'active';
  bool _loading = true;
  bool _submitting = false;
  // Set when the data this form needs could not be read. The form is then not
  // shown: blank fields that look editable would let a save overwrite the real
  // values (manufacturer, model, notes) with nothing.
  String? _loadError;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (_isEdit) {
        // Editing needs the device itself, not the list of sites (a device's
        // site is not editable here).
        final d = await getIt<DeviceDetailRepository>().show(widget.existingId!);
        if (!mounted) return;
        setState(() {
          _nameCtrl.text = d.name;
          _serialCtrl.text = d.serialNumber ?? '';
          _manufacturerCtrl.text = d.manufacturer ?? '';
          _modelCtrl.text = d.model ?? '';
          _notesCtrl.text = d.notes ?? '';
          _status = d.status ?? 'active';
          _siteId = d.siteId;
          _loading = false;
        });
      } else {
        // Creating needs a site to attach the device to.
        final sites = await getIt<SiteRepository>().list(forceRefresh: true);
        if (!mounted) return;
        setState(() {
          _sites = sites;
          _siteId = sites.isNotEmpty ? sites.first.id : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = ErrorMessage.from(e);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      if (_isEdit) {
        await getIt<DeviceDetailRepository>().update(
          id: widget.existingId!,
          name: _nameCtrl.text.trim(),
          serialNumber: _serialCtrl.text.trim(),
          manufacturer: _manufacturerCtrl.text.trim().isEmpty
              ? null
              : _manufacturerCtrl.text.trim(),
          model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
          status: _status,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        // Also invalidate the picker cache so Cycle Create sees the change.
        getIt<DeviceRepository>().invalidateCache();
        if (!mounted) return;
        AppSnackbar.show(context, 'Appareil mis à jour.',
            kind: SnackKind.success);
      } else {
        if (_siteId == null) {
          AppSnackbar.show(context, 'Créez d\'abord un site.',
              kind: SnackKind.warning);
          setState(() => _submitting = false);
          return;
        }
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
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _kindLabel => switch (_kind) {
        'autoclave' => 'Autoclave',
        'washer_disinfector' => 'Laveur désinfecteur',
        'sealer' => 'Thermoscelleuse',
        _ => 'Autre appareil',
      };

  /// The device as it will appear in the list, updated as the person types.
  Widget _preview() {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [_nameCtrl, _serialCtrl, _manufacturerCtrl, _modelCtrl],
      ),
      builder: (context, _) {
        final name = _nameCtrl.text.trim();
        final serial = _serialCtrl.text.trim();
        final make = [_manufacturerCtrl.text.trim(), _modelCtrl.text.trim()]
            .where((s) => s.isNotEmpty)
            .join(' ');
        String? site;
        for (final s in _sites) {
          if (s.id == _siteId) site = s.name;
        }
        return PreviewCard(
          key: const Key('device-preview'),
          mark: const EntityMark.icon(Icons.precision_manufacturing_outlined),
          eyebrow: _kindLabel.toUpperCase(),
          title: name.isEmpty ? 'Nom de l\'appareil' : name,
          titleIsPlaceholder: name.isEmpty,
          tags: [
            if (make.isNotEmpty) InfoTag(make, icon: Icons.factory_outlined),
            if (serial.isNotEmpty) InfoTag('N° $serial', icon: Icons.tag),
            if (site != null) InfoTag(site, icon: Icons.business_outlined),
          ],
        );
      },
    );
  }

  Widget _centered(Widget child) => SizedBox(
        height: 240,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _centered(const Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return _centered(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isEdit
                  ? 'Impossible de charger cet appareil. Rien n\'a été modifié.'
                  : 'Impossible de charger les sites.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
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
                    _isEdit ? 'Modifier l\'appareil' : 'Nouvel appareil',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isEdit
                        ? 'Passer un appareil en maintenance le retire des '
                            'cycles possibles.'
                        : 'Une fois créé, ajoutez ses programmes de '
                            'stérilisation depuis sa fiche.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _preview(),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Appareil',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      if (!_isEdit)
                        _sites.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.warningLight,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.control),
                                ),
                                child: const Text(
                                  'Aucun site disponible. Créez d\'abord un '
                                  'site dans Sites & Espaces.',
                                  style: AppTypography.caption,
                                ),
                              )
                            : AppDropdown<String>(
                                label: 'Site *',
                                value: _siteId,
                                options: _sites
                                    .map((s) => AppDropdownOption(
                                        value: s.id, label: s.name))
                                    .toList(),
                                onChanged: (v) => setState(() => _siteId = v),
                              ),
                      AppTextField(
                        label: 'Nom *',
                        hint: 'Melag Vacuklav 40B+',
                        controller: _nameCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                      AppTextField(
                        label: 'N° de série *',
                        hint: 'MEL-001',
                        controller: _serialCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                      ),
                      if (!_isEdit)
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
                          onChanged: (v) =>
                              setState(() => _kind = v ?? 'autoclave'),
                        )
                      else
                        AppDropdown<String>(
                          label: 'Statut',
                          value: _status,
                          options: const [
                            AppDropdownOption(value: 'active', label: 'Actif'),
                            AppDropdownOption(
                                value: 'maintenance',
                                label: 'En maintenance'),
                            AppDropdownOption(
                                value: 'decommissioned',
                                label: 'Hors service'),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'active'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Constructeur',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppTextField(
                        label: 'Fabricant',
                        hint: 'Melag',
                        controller: _manufacturerCtrl,
                      ),
                      AppTextField(
                        label: 'Modèle',
                        hint: 'Vacuklav 40B+',
                        controller: _modelCtrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Notes',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppTextArea(
                        label: 'Notes',
                        controller: _notesCtrl,
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
                    : 'Enregistrer l\'appareil',
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
