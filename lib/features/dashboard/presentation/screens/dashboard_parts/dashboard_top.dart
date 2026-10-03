part of '../dashboard_screen.dart';

/// The bar that stays on screen: the product mark and the clinic on the left,
/// the alert bell (with a dot when something is open) and the account on the
/// right.
class _TopBar extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  const _TopBar({required this.name, required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final clinic = session.tenantName;
    final canAlerts = session.hasPermission('alerts.view');
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.backgroundApp,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.navyHeader,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SteryMed',
                  style: AppTypography.cardTitle.copyWith(
                    color: AppColors.navyHeader,
                    height: 1.1,
                  ),
                ),
                if (clinic != null && clinic.isNotEmpty)
                  Text(
                    clinic.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      fontSize: 10,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (canAlerts)
            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                final open = state is DashboardLoaded
                    ? state.data.kpis
                        .where((k) => k.id == 'pending_alerts')
                        .map((k) => k.value ?? 0)
                        .fold<int>(0, (a, b) => a + b)
                    : 0;
                return _BellButton(
                  hasOpen: open > 0,
                  onTap: () => context.openRoute(Routes.alerts),
                );
              },
            ),
          ProfileMenu(displayName: name, email: email, role: role),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool hasOpen;
  final VoidCallback onTap;
  const _BellButton({required this.hasOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hasOpen ? 'Alertes : certaines sont ouvertes' : 'Alertes',
      child: InkWell(
        key: const Key('dashboard-bell'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.backgroundCard,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_outlined, size: 20),
              if (hasOpen)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundCard,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String greeting;
  final DashboardData data;

  const _Header({
    required this.name,
    required this.email,
    required this.role,
    required this.greeting,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TABLEAU DE BORD', style: AppTypography.eyebrow),
              const SizedBox(height: 2),
              Text(
                '$greeting, $name',
                style: AppTypography.pageTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      RoleLabels.of(role),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    RoleLabels.focusOf(role),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _FreshnessPill(data: data),
      ],
    );
  }
}

/// Whether what is on screen can be trusted right now: read from the server
/// and complete, partly missing, or an earlier read kept after a failed
/// refresh.
class _FreshnessPill extends StatelessWidget {
  final DashboardData data;
  const _FreshnessPill({required this.data});

  @override
  Widget build(BuildContext context) {
    final (label, color) = data.stale
        ? ('Hors ligne', AppColors.textSecondary)
        : data.hasUnavailable
            ? ('Partiel', AppColors.warning)
            : ('À jour', AppColors.success);
    return Container(
      key: const Key('dashboard-freshness'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// KPI grid
// ─────────────────────────────────────────────────────────────────────────
