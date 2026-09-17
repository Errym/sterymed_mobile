import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/severity_badge.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../data/models/alert_data.dart';
import '../bloc/alert_list_bloc.dart';

class AlertListScreen extends StatelessWidget {
  const AlertListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AlertListBloc(ctx.read())..add(const LoadAlerts()),
      child: const _AlertListView(),
    );
  }
}

class _AlertListView extends StatelessWidget {
  const _AlertListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Alertes')),
      body: BlocBuilder<AlertListBloc, AlertListState>(
        builder: (context, state) {
          if (state.status == AlertListStatus.loading && state.alerts.isEmpty) {
            return const LoadingView(message: 'Chargement des alertes...');
          }

          if (state.status == AlertListStatus.failure && state.alerts.isEmpty) {
            return ErrorView(
              message: state.error ?? 'Une erreur est survenue.',
              onRetry: () =>
                  context.read<AlertListBloc>().add(const LoadAlerts()),
            );
          }

          if (state.alerts.isEmpty) {
            return const EmptyView(
              title: 'Aucune alerte active',
              message: 'Tout est en ordre pour le moment.',
              icon: Icons.notifications_none,
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<AlertListBloc>().add(const RefreshAlerts()),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (state.criticalAlerts.isNotEmpty)
                  _Group(
                    title: 'Critique',
                    alerts: state.criticalAlerts,
                    color: AppColors.danger,
                  ),
                if (state.warningAlerts.isNotEmpty)
                  _Group(
                    title: 'Avertissement',
                    alerts: state.warningAlerts,
                    color: AppColors.warning,
                  ),
                if (state.infoAlerts.isNotEmpty)
                  _Group(
                    title: 'Information',
                    alerts: state.infoAlerts,
                    color: AppColors.info,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<AlertData> alerts;
  final Color color;

  const _Group({
    required this.title,
    required this.alerts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            title,
            style: AppTypography.sectionTitle.copyWith(color: color),
          ),
        ),
        for (final alert in alerts)
          _AlertTile(
            alert: alert,
            onResolve: () async {
              final confirmed = await ConfirmationDialog.show(
                context,
                title: 'Résoudre l\'alerte ?',
                message:
                    'Êtes-vous sûr de vouloir marquer cette alerte comme résolue ?',
                confirmLabel: 'Résoudre',
              );
              if (confirmed && context.mounted) {
                context.read<AlertListBloc>().add(ResolveAlert(alert.id));
              }
            },
          ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertData alert;
  final VoidCallback onResolve;

  const _AlertTile({required this.alert, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SeverityBadge(severity: alert.severity.name),
              const Spacer(),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt),
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(alert.message, style: AppTypography.bodyStrong),
          if (alert.subjectLabel != null) ...[
            const SizedBox(height: 2),
            Text(alert.subjectLabel!, style: AppTypography.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onResolve,
              child: const Text('Marquer comme résolu'),
            ),
          ),
        ],
      ),
    );
  }
}
