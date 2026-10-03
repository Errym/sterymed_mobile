import '../../../../core/utils/extensions/context_ext.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/feedback/pending_changes_banner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/files/file_export_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/saved_file_sheet.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/label_scan_result.dart';
import '../../data/models/label_usage_data.dart';
import '../../data/repositories/label_repository.dart';
import '../../data/repositories/label_usage_repository.dart';
import '../bloc/label_detail_bloc.dart';

class LabelDetailScreen extends StatelessWidget {
  final String code;
  const LabelDetailScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LabelDetailBloc(
        ctx.read<LabelRepository>(),
        ctx.read<LabelUsageRepository>(),
      )..add(LoadLabel(code)),
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
      appBar: AppBar(
        title: const Text('Étiquette'),
        leading: AppBackButton.maybe(context),
      ),
      body: BlocBuilder<LabelDetailBloc, LabelDetailState>(
        builder: (context, state) {
          if (state.status == LabelDetailStatus.loading ||
              state.status == LabelDetailStatus.initial) {
            return const LoadingView(message: 'Chargement de l\'étiquette...');
          }
          if (state.status == LabelDetailStatus.failure) {
            return ErrorView(message: state.error ?? 'Étiquette introuvable.');
          }

          final result = state.result;
          if (result == null) return const SizedBox.shrink();

          final canRecordUsage = getIt<SessionStore>().hasPermission(
            'usages.manage',
          );

          var i = 0;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              PendingChangesBanner(resourceKey: 'label:${result.labelId}'),
              AnimatedListItem(
                index: i++,
                child: _StatusHeader(result: result),
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedListItem(
                index: i++,
                child: _InfoSection(result: result),
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedListItem(
                index: i++,
                child: _UsageHistorySection(
                  history: state.history,
                  loading: state.historyLoading,
                  failed: state.historyFailed,
                ),
              ),
              // The proof for an inspector: only when a use was recorded.
              if (state.history.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AnimatedListItem(
                  index: i++,
                  child: _DossierButton(labelId: result.labelId),
                ),
              ],
              // Hidden outright (not just disabled) for a role without
              // `usages.manage` — a viewer/stock_manager/releaser scanning
              // a valid label should never see an action they'd only get
              // a 403 for after filling in the whole form.
              if (canRecordUsage) ...[
                const SizedBox(height: AppSpacing.lg),
                AnimatedListItem(
                  index: i++,
                  child: PrimaryButton(
                    label: 'Enregistrer utilisation',
                    icon: Icons.assignment_turned_in_outlined,
                    onPressed: !result.canRecordUsage
                        ? null
                        : () => context.openRoute(
                            Routes.labelsUsage(result.labelId),
                            extra: result,
                          ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// "Exporter le dossier (PDF)": the evidence dossier of the recorded use, as a
/// file saved on the device that can be opened, shown to an inspector or sent.
class _DossierButton extends StatefulWidget {
  final String labelId;
  const _DossierButton({required this.labelId});

  @override
  State<_DossierButton> createState() => _DossierButtonState();
}

class _DossierButtonState extends State<_DossierButton> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await getIt<FileExportService>().saveFromApi(
        ApiEndpoints.labelUsageDossier(widget.labelId),
        baseName: 'dossier-preuve',
        extension: 'pdf',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await SavedFileSheet.show(
        context,
        file: file,
        title: 'Dossier enregistré',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('label-export-dossier'),
      onPressed: _busy ? null : _export,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_busy ? 'Export en cours…' : 'Exporter le dossier (PDF)'),
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
      case LabelScanStatus.created:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        icon = Icons.print_disabled_outlined;
        label = 'Étiquette non imprimée';
        break;
      case LabelScanStatus.printed:
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.verified_outlined;
        label = 'Étiquette valide';
        break;
      case LabelScanStatus.used:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        icon = Icons.check_circle_outline;
        label = 'Étiquette déjà utilisée';
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
      case LabelScanStatus.voided:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        icon = Icons.block_outlined;
        label = 'Étiquette annulée';
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: fg),
          ),
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
  final LabelScanResult result;
  const _InfoSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final rows = <Widget>[
      _row(
        Icons.autorenew,
        'Cycle',
        'N°${result.cycleNumber} · article ${result.sequenceInCycle}',
      ),
      _row(
        Icons.precision_manufacturing_outlined,
        'Appareil',
        result.deviceName,
      ),
      _row(Icons.meeting_room_outlined, 'Site', result.siteName),
      _row(
        Icons.event_available_outlined,
        'Stérilisé le',
        dateFmt.format(result.sterilizedAt),
      ),
      _row(
        Icons.event_busy_outlined,
        'Expire le',
        dateFmt.format(result.useByDate),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.borderLight),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
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

class _UsageHistorySection extends StatelessWidget {
  final List<LabelUsageData> history;
  final bool loading;
  final bool failed;
  const _UsageHistorySection({
    required this.history,
    required this.loading,
    this.failed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique d\'utilisation',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Historique indisponible : impossible de vérifier si '
                      'cette étiquette a déjà été utilisée. Réessayez.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Aucune utilisation enregistrée pour cette étiquette.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < history.length; i++) ...[
              _HistoryRow(usage: history[i]),
              if (i != history.length - 1)
                const Divider(
                  height: AppSpacing.lg,
                  color: AppColors.borderLight,
                ),
            ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final LabelUsageData usage;
  const _HistoryRow({required this.usage});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.medical_information_outlined,
            size: 16,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usage.procedure, style: AppTypography.bodyStrong),
              const SizedBox(height: 2),
              Text(
                '${usage.patientReference} · ${dateFmt.format(usage.usedAt)}'
                '${usage.practitionerName != null ? ' · ${usage.practitionerName}' : ''}',
                style: AppTypography.caption,
              ),
              if (usage.notes != null && usage.notes!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(usage.notes!, style: AppTypography.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
