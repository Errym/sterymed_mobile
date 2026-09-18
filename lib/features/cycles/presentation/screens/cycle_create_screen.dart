import 'dart:async';

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
import '../../data/models/device_program_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/device_program_repository.dart';
import '../../data/repositories/device_repository.dart';

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
      final selected = _deviceId ??
          (devices.isNotEmpty ? devices.first.id : null);
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
        _deviceError = e.toString();
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
        _programError = e.toString();
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
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
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
            const _BannerCard(),
            const SizedBox(height: AppSpacing.lg),

            // ── Device ──
            const _SectionLabel('APPAREIL AUTOCLAVE'),
            _buildDeviceSection(),
            const SizedBox(height: AppSpacing.lg),

            // ── Programme ──
            const _SectionLabel('PROGRAMME DE STÉRILISATION'),
            _buildProgrammeSection(),
            const SizedBox(height: AppSpacing.lg),

            // ── Operator ──
            const _SectionLabel('OPÉRATEUR CHARGÉ DU CYCLE'),
            _OperatorCard(name: operatorName),
            const SizedBox(height: AppSpacing.lg),

            // ── Notes ──
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
              onPressed: _canSubmit() ? _submit : null,
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
      return _ErrorCard(error: _deviceError!, onRetry: _loadDevices);
    }
    if (_devices.isEmpty) {
      return _EmptyDevicesCard(onCreateDevice: _openDevicesTab);
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
      return const _Hint(
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
      return _ErrorCard(
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'Sélectionnez l\'appareil et le programme de la charge.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevicesCard extends StatelessWidget {
  final VoidCallback onCreateDevice;
  const _EmptyDevicesCard({required this.onCreateDevice});

  @override
  Widget build(BuildContext context) {
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
                  'Aucun appareil disponible',
                  style: AppTypography.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Pour créer un cycle, vous devez d\'abord ajouter un appareil.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onCreateDevice,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Créer un appareil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.danger, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Impossible de charger les données',
                  style: AppTypography.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(error, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(text, style: AppTypography.caption),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  final String name;
  const _OperatorCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(name, style: AppTypography.bodyStrong),
          const Spacer(),
          const Text('Vous', style: AppTypography.caption),
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
