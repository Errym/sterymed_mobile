import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../data/models/label_data.dart';
import '../../data/models/label_scan_result.dart';
import '../bloc/label_detail_bloc.dart';

class LabelDetailScreen extends StatelessWidget {
  final String code;
  const LabelDetailScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LabelDetailBloc(ctx.read())..add(LoadLabel(code)),
      child: const _LabelDetailView(),
    );
  }
}

class _LabelDetailView extends StatelessWidget {
  const _LabelDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Étiquette')),
      body: BlocBuilder<LabelDetailBloc, LabelDetailState>(
        builder: (context, state) {
          if (state.status == LabelDetailStatus.loading) {
            return const LoadingView(message: 'Chargement de l\'étiquette...');
          }
          if (state.status == LabelDetailStatus.failure) {
            return ErrorView(message: state.error ?? 'Étiquette introuvable.');
          }

          final result = state.result;
          if (result == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _StatusHeader(result: result),
              const SizedBox(height: AppSpacing.md),
              if (result.label != null) _InfoSection(label: result.label!),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Enregistrer utilisation',
                icon: Icons.assignment_turned_in_outlined,
                onPressed: result.label == null || result.isBlocked
                    ? null
                    : () => context.go(Routes.labelsUsage(result.label!.id)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final LabelScanResult result;
  const _StatusHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;
    switch (result.status) {
      case LabelScanStatus.valid:
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.verified_outlined;
        label = 'Étiquette valide';
        break;
      case LabelScanStatus.expired:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        icon = Icons.timer_off_outlined;
        label = 'Étiquette expirée';
        break;
      case LabelScanStatus.recalled:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        icon = Icons.report_gmailerrorred_outlined;
        label = 'Étiquette rappelée';
        break;
      case LabelScanStatus.unknown:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        icon = Icons.help_outline;
        label = 'Statut inconnu';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.sectionTitle.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final LabelData label;
  const _InfoSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _row(Icons.qr_code_2, 'Code', label.code),
          if (label.productName != null)
            _row(Icons.inventory_2_outlined, 'Produit', label.productName!),
          if (label.batchNumber != null)
            _row(Icons.numbers, 'Lot', label.batchNumber!),
          if (label.cycleNumber != null)
            _row(Icons.autorenew, 'Cycle', label.cycleNumber!),
          if (label.deviceName != null)
            _row(Icons.precision_manufacturing_outlined, 'Appareil',
                label.deviceName!),
          if (label.sterilizedAt != null)
            _row(Icons.event_available_outlined, 'Stérilisé le',
                dateFmt.format(label.sterilizedAt!)),
          if (label.expiresAt != null)
            _row(Icons.event_busy_outlined, 'Expire le',
                dateFmt.format(label.expiresAt!)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}
