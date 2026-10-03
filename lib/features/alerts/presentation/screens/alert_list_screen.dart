import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/severity_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/alert_data.dart';
import '../bloc/alert_list_bloc.dart';

/// The alert kinds the server raises (`AlertType`). There is deliberately no
/// "overdue control" entry: the server does not raise that alert yet.
const alertTypeLabels = <String, String>{
  'low_stock': 'Stock bas',
  'near_expiry': 'Péremption proche',
  'expired': 'Périmé',
  'failed_cycle': 'Cycle en échec',
};

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

class _AlertListView extends StatefulWidget {
  const _AlertListView();

  @override
  State<_AlertListView> createState() => _AlertListViewState();
}

class _AlertListViewState extends State<_AlertListView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final threshold = _controller.position.maxScrollExtent - 200;
    if (_controller.position.pixels >= threshold) {
      context.read<AlertListBloc>().add(const LoadMoreAlerts());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('alerts.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Alertes')),
      body: BlocListener<AlertListBloc, AlertListState>(
        // The answer to each "resolve" tap, success or the real reason.
        listenWhen: (a, b) => a.notice != b.notice && b.notice != null,
        listener: (context, state) {
          final n = state.notice!;
          AppSnackbar.show(
            context,
            n.message,
            kind: n.isError ? SnackKind.error : SnackKind.success,
          );
        },
        child: Column(
          children: [
            const _FilterBar(),
            Expanded(child: _Body(controller: _controller, canManage: canManage)),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertListBloc, AlertListState>(
      buildWhen: (a, b) =>
          a.typeFilter != b.typeFilter || a.stateFilter != b.stateFilter,
      builder: (context, state) {
        void apply({String? type, String? stateValue = 'open'}) =>
            context.read<AlertListBloc>().add(
                  FilterAlerts(type: type, state: stateValue),
                );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              for (final (label, value) in const [
                ('Ouvertes', 'open'),
                ('Résolues', 'resolved'),
                ('Toutes', null),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    key: Key('alert-state-${value ?? 'all'}'),
                    label: Text(label),
                    selected: state.stateFilter == value,
                    onSelected: (_) =>
                        apply(type: state.typeFilter, stateValue: value),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              for (final entry in alertTypeLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    key: Key('alert-type-${entry.key}'),
                    label: Text(entry.value),
                    selected: state.typeFilter == entry.key,
                    onSelected: (on) => apply(
                      type: on ? entry.key : null,
                      stateValue: state.stateFilter,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final ScrollController controller;
  final bool canManage;
  const _Body({required this.controller, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertListBloc, AlertListState>(
      builder: (context, state) {
        if (state.status == AlertListStatus.loading && state.alerts.isEmpty) {
          return const LoadingView(message: 'Chargement des alertes...');
        }

        if (state.status == AlertListStatus.failure && state.alerts.isEmpty) {
          return ErrorView(
            message: state.error ?? 'Une erreur est survenue.',
            onRetry: () => context.read<AlertListBloc>().add(const LoadAlerts()),
          );
        }

        if (state.alerts.isEmpty) {
          return EmptyView(
            title: state.hasActiveFilter
                ? 'Aucune alerte pour ce filtre'
                : 'Aucune alerte active',
            message: state.hasActiveFilter
                ? 'Changez de filtre pour voir les autres alertes.'
                : 'Tout est en ordre pour le moment.',
            icon: Icons.notifications_none,
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              context.read<AlertListBloc>().add(const RefreshAlerts()),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // The list on screen is the last one that loaded: say so when
              // the latest refresh did not work.
              if (state.status == AlertListStatus.failure)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    key: const Key('alerts-stale-banner'),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Actualisation impossible : cette liste peut être périmée.',
                            style: AppTypography.caption,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context
                              .read<AlertListBloc>()
                              .add(const RefreshAlerts()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              _Summary(
                critical: state.criticalAlerts.length,
                warning: state.warningAlerts.length,
                info: state.infoAlerts.length,
                resolvedView: state.stateFilter == 'resolved',
              ),
              const SizedBox(height: AppSpacing.xs),
              if (state.criticalAlerts.isNotEmpty)
                AnimatedListItem(
                  index: 0,
                  child: _Group(
                    title: 'Critique',
                    alerts: state.criticalAlerts,
                    color: AppColors.danger,
                    icon: Icons.error_outline,
                    canManage: canManage,
                    resolving: state.resolving,
                  ),
                ),
              if (state.warningAlerts.isNotEmpty)
                AnimatedListItem(
                  index: 1,
                  child: _Group(
                    title: 'Avertissement',
                    alerts: state.warningAlerts,
                    color: AppColors.warning,
                    icon: Icons.warning_amber_outlined,
                    canManage: canManage,
                    resolving: state.resolving,
                  ),
                ),
              if (state.infoAlerts.isNotEmpty)
                AnimatedListItem(
                  index: 2,
                  child: _Group(
                    title: 'Information',
                    alerts: state.infoAlerts,
                    color: AppColors.info,
                    icon: Icons.info_outline,
                    canManage: canManage,
                    resolving: state.resolving,
                  ),
                ),
              if (state.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// What needs attention at a glance: how many alerts per severity.
class _Summary extends StatelessWidget {
  final int critical;
  final int warning;
  final int info;
  final bool resolvedView;
  const _Summary({
    required this.critical,
    required this.warning,
    required this.info,
    required this.resolvedView,
  });

  @override
  Widget build(BuildContext context) {
    final total = critical + warning + info;
    final calm = critical == 0 && !resolvedView;
    return Container(
      key: const Key('alerts-summary'),
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
          Text(
            resolvedView ? 'ALERTES RÉSOLUES' : 'À TRAITER',
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 2),
          Text(
            resolvedView
                ? '$total alerte${total > 1 ? 's' : ''} déjà traitée${total > 1 ? 's' : ''}'
                : critical > 0
                    ? '$critical alerte${critical > 1 ? 's' : ''} '
                        'critique${critical > 1 ? 's' : ''} '
                        'requ${critical > 1 ? 'ièrent' : 'iert'} une action'
                    : calm && total > 0
                        ? 'Aucune urgence · $total sous surveillance'
                        : 'Rien à signaler',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Count('Critiques', critical, AppColors.danger),
              const SizedBox(width: AppSpacing.xs),
              _Count('Avertissements', warning, AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              _Count('Infos', info, AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Count(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: AppTypography.kpiNumber.copyWith(
                color: value == 0 ? AppColors.textTertiary : color,
                fontSize: 22,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<AlertData> alerts;
  final Color color;
  final IconData icon;
  final bool canManage;
  final Set<String> resolving;

  const _Group({
    required this.title,
    required this.alerts,
    required this.color,
    required this.icon,
    required this.canManage,
    required this.resolving,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.sectionTitle.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${alerts.length}',
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final alert in alerts)
          _AlertTile(
            alert: alert,
            color: color,
            resolving: resolving.contains(alert.id),
            // Hidden, not disabled, for roles that cannot resolve; and an
            // already-resolved alert has nothing left to resolve.
            onResolve: (!canManage || alert.resolved)
                ? null
                : () async {
                    final confirmed = await ConfirmationDialog.show(
                      context,
                      title: 'Résoudre l\'alerte ?',
                      message: 'Êtes-vous sûr de vouloir marquer cette '
                          'alerte comme résolue ?',
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

/// "il y a 25 min", "hier", "il y a 3 j": how long the alert has been waiting.
String alertAge(DateTime created, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(created);
  if (d.inMinutes < 1) return 'à l\'instant';
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'il y a ${d.inHours} h';
  if (d.inDays == 1) return 'hier';
  return 'il y a ${d.inDays} j';
}

/// Where an alert's subject can be looked at, or null when there is no screen.
({String label, IconData icon, String route})? alertTarget(AlertData a) {
  final id = a.subjectId;
  if (a.subjectType.endsWith('Cycle') && id != null) {
    return (
      label: 'Voir le cycle',
      icon: Icons.autorenew,
      route: Routes.cyclesDetail(id),
    );
  }
  switch (a.type) {
    case 'low_stock':
      return (
        label: 'Voir le stock',
        icon: Icons.inventory_2_outlined,
        route: Routes.stock,
      );
    case 'near_expiry':
    case 'expired':
      return (
        label: 'Voir les lots',
        icon: Icons.qr_code_2,
        route: Routes.batches,
      );
  }
  return null;
}

IconData _typeIcon(String type) => switch (type) {
      'low_stock' => Icons.inventory_2_outlined,
      'near_expiry' => Icons.hourglass_bottom,
      'expired' => Icons.event_busy_outlined,
      'failed_cycle' => Icons.sync_problem_outlined,
      _ => Icons.notifications_outlined,
    };

class _AlertTile extends StatelessWidget {
  final AlertData alert;
  final Color color;
  final bool resolving;
  final VoidCallback? onResolve;

  const _AlertTile({
    required this.alert,
    required this.color,
    required this.resolving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final typeLabel = alertTypeLabels[alert.type] ?? 'Alerte';
    final target = alertTarget(alert);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        EntityMark.icon(
                          _typeIcon(alert.type),
                          background: color.withValues(alpha: 0.12),
                          foreground: color,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeLabel.toUpperCase(),
                                style: AppTypography.eyebrow,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                alertAge(alert.createdAt),
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        SeverityBadge(severity: alert.severity.name),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(alert.message, style: AppTypography.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      'Détectée le ${fmt.format(alert.createdAt)}',
                      style: AppTypography.caption,
                    ),
                    if (alert.resolved) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          'Résolue',
                          if (alert.resolvedAt != null)
                            'le ${fmt.format(alert.resolvedAt!)}',
                          if (alert.resolvedByName != null)
                            'par ${alert.resolvedByName}',
                        ].join(' '),
                        key: Key('alert-resolved-${alert.id}'),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.success),
                      ),
                    ],
                    if (target != null || onResolve != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (target != null)
                            OutlinedButton.icon(
                              key: Key('alert-open-${alert.id}'),
                              onPressed: () => context.openRoute(target.route),
                              icon: Icon(target.icon, size: 16),
                              label: Text(target.label),
                            ),
                          if (onResolve != null)
                            resolving
                                ? const Padding(
                                    padding: EdgeInsets.all(AppSpacing.sm),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : TextButton(
                                    onPressed: onResolve,
                                    child: const Text('Marquer comme résolu'),
                                  ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
