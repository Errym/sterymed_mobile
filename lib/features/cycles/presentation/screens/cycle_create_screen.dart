import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/device_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/device_repository.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _notesCtrl = TextEditingController();
  List<DeviceData> _devices = [];
  String? _deviceId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await getIt<DeviceRepository>().list();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_deviceId == null) {
      AppSnackbar.show(context, 'Sélectionnez un appareil.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<CycleRepository>().create({
        'device_id': _deviceId,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.show(context, 'Cycle initialisé.', kind: SnackKind.success);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = getIt<SessionStore>();
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Initialiser un Nouveau Cycle'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.add_box_outlined,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cycle de Stérilisation Normé EN 13060',
                              style: AppTypography.bodyStrong,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sélectionnez l\'appareil autoclave pour la charge.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('APPAREIL AUTOCLAVE'),
                AppDropdown<String>(
                  value: _deviceId,
                  hint: _devices.isEmpty
                      ? 'Aucun appareil disponible'
                      : 'Sélectionner un appareil',
                  options: _devices
                      .map((d) => AppDropdownOption(
                            value: d.id,
                            label: d.name,
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _deviceId = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('OPÉRATEUR CHARGÉ DU CYCLE'),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        currentUser.userName ?? 'Utilisateur actuel',
                        style: AppTypography.bodyStrong,
                      ),
                      const Spacer(),
                      const Text('Vous', style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('NOTES SUR LA CHARGE (OPTIONNEL)'),
                AppTextArea(
                  controller: _notesCtrl,
                  hint:
                      'Ex : Cassettes chirurgicales Dr. Watson, sachets turbines...',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Initialiser & Charger les Sachets',
                  icon: Icons.add_circle_outline,
                  isLoading: _submitting,
                  onPressed: _devices.isEmpty ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          letterSpacing: 0.4,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
