part of '../alert_list_screen.dart';

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
