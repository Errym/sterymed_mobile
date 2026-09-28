import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/device_data.dart';
import '../../data/models/device_program_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/device_program_repository.dart';
import '../../data/repositories/device_repository.dart';
import '../widgets/cycle_create_banner_card.dart';
import '../widgets/cycle_create_empty_devices_card.dart';
import '../widgets/cycle_create_error_card.dart';
import '../widgets/cycle_create_hint.dart';
import '../widgets/cycle_create_operator_card.dart';
import '../widgets/cycle_create_section_label.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});
  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _notesCtrl = TextEditingController();

  // Devices
  List<DeviceData> _devices = [];
  String? _deviceId;
  bool _loadingDevices = true;
  String? _deviceError;

  // Programmes (depends on selected device)
  List<DeviceProgramData> _programs = [];
  String? _programId;
  bool _loadingPrograms = false;
  String? _programError;

  bool _submitting = false;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = getIt<DeviceRepository>().changes.listen((_) {
      if (mounted) _loadDevices();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loadingDevices = true;
      _deviceError = null;
    });
    try {
      final repo = getIt<DeviceRepository>();
      repo.invalidateCache();
      final devices = await repo.list(forceRefresh: true);
      if (!mounted) return;
      final selected =
          _deviceId ?? (devices.isNotEmpty ? devices.first.id : null);
      setState(() {
        _devices = devices;
        _deviceId = selected;
        _loadingDevices = false;
      });
      // Load programmes for the selected device
      if (selected != null) {
        await _loadPrograms(selected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDevices = false;
        _deviceError = ErrorMessage.from(e);
      });
    }
  }

  Future<void> _loadPrograms(String deviceId) async {
    setState(() {
      _loadingPrograms = true;
      _programError = null;
      _programId = null;
      _programs = [];
    });
    try {
      final repo = getIt<DeviceProgramRepository>();
      final programs = await repo.list(deviceId, forceRefresh: true);
      if (!mounted || _deviceId != deviceId) return;
      setState(() {
        _programs = programs;
        _programId = programs.isNotEmpty ? programs.first.id : null;
        _loadingPrograms = false;
      });
    } catch (e) {
      if (!mounted || _deviceId != deviceId) return;
      setState(() {
        _loadingPrograms = false;
        _programError = ErrorMessage.from(e);
      });
    }
  }

  Future<void> _openDevicesTab() async {
    try {
      await context.push('/app/devices');
    } catch (_) {
      if (mounted) context.go('/app/devices');
      return;
    }
    if (!mounted) return;
    await _loadDevices();
  }

  Future<void> _submit() async {
    if (_deviceId == null) {
      AppSnackbar.show(context, 'Sélectionnez un appareil.',
          kind: SnackKind.warning);
      return;
    }
    if (_programId == null) {
      AppSnackbar.show(context, 'Sélectionnez un programme.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<CycleRepository>().create({
        'device_id': _deviceId,
        'device_program_id': _programId,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.show(context, 'Cycle initialisé.', kind: SnackKind.success);

      if (Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/app/cycles');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _canSubmit() =>
      !_loadingDevices &&
      !_loadingPrograms &&
      !_submitting &&
      _deviceId != null &&
      _programId != null;

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final operatorName = session.userName ?? 'Utilisateur actuel';

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Initialiser un Nouveau Cycle',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
            onPressed: _loadingDevices ? null : _loadDevices,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const AnimatedListItem(index: 0, child: CycleCreateBannerCard()),
            const SizedBox(height: AppSpacing.lg),

            // ── Device ──
            AnimatedListItem(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CycleCreateSectionLabel('APPAREIL AUTOCLAVE'),
                  _buildDeviceSection(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Programme ──
            AnimatedListItem(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CycleCreateSectionLabel('PROGRAMME DE STÉRILISATION'),
                  _buildProgrammeSection(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Operator ──
            AnimatedListItem(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CycleCreateSectionLabel('OPÉRATEUR CHARGÉ DU CYCLE'),
                  CycleCreateOperatorCard(name: operatorName),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Notes ──
            AnimatedListItem(
              index: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CycleCreateSectionLabel(
                      'NOTES SUR LA CHARGE (OPTIONNEL)'),
                  AppTextArea(
                    controller: _notesCtrl,
                    hint: 'Ex : Cassettes chirurgicales Dr. Watson, sachets '
                        'turbines...',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AnimatedListItem(
              index: 5,
              child: PrimaryButton(
                label: 'Initialiser & Charger les Sachets',
                icon: Icons.add_circle_outline,
                isLoading: _submitting,
                onPressed: _canSubmit() ? _submit : null,
              ),
            ),
            if (!_canSubmit() && !_loadingDevices && !_loadingPrograms) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _programs.isEmpty
                    ? 'Ajoutez un programme à cet appareil pour continuer.'
                    : 'Sélectionnez un appareil et un programme.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection() {
    if (_loadingDevices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_deviceError != null) {
      return CycleCreateErrorCard(error: _deviceError!, onRetry: _loadDevices);
    }
    if (_devices.isEmpty) {
      return CycleCreateEmptyDevicesCard(onCreateDevice: _openDevicesTab);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDropdown<String>(
          value: _deviceId,
          hint: 'Sélectionner un appareil',
          options: _devices
              .map((d) => AppDropdownOption(value: d.id, label: d.name))
              .toList(),
          onChanged: (v) {
            if (v == null || v == _deviceId) return;
            setState(() => _deviceId = v);
            _loadPrograms(v);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openDevicesTab,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter un appareil'),
          ),
        ),
      ],
    );
  }

  Widget _buildProgrammeSection() {
    if (_deviceId == null) {
      return const CycleCreateHint(
        'Sélectionnez d\'abord un appareil.',
      );
    }
    if (_loadingPrograms) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_programError != null) {
      return CycleCreateErrorCard(
        error: _programError!,
        onRetry: () => _loadPrograms(_deviceId!),
      );
    }
    if (_programs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: AppColors.warning, size: 20),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Aucun programme pour cet appareil',
                    style: AppTypography.bodyStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Ajoutez au moins un programme (température + durée) dans la '
              'fiche de l\'appareil.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openDevicesTab,
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Gérer les programmes'),
              ),
            ),
          ],
        ),
      );
    }
    return AppDropdown<String>(
      value: _programId,
      hint: 'Sélectionner un programme',
      options: _programs
          .map((p) => AppDropdownOption(value: p.id, label: p.displayLabel))
          .toList(),
      onChanged: (v) => setState(() => _programId = v),
    );
  }
}
