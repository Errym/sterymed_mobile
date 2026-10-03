part of '../dashboard_screen.dart';

/// One of the three headline figures. [value] null means "could not be read":
/// shown as a dash, never as a zero.
class _KpiSpec {
  final String label;
  final int? value;
  final bool approximate;
  final IconData icon;
  final Color accent;
  final String route;

  /// Something that wants action: the tile is tinted warm.
  final bool attention;
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.route,
    this.approximate = false,
    this.attention = false,
  });
}

class _KpiRow extends StatelessWidget {
  final List<_KpiSpec> specs;
  const _KpiRow({required this.specs});

  @override
  Widget build(BuildContext context) {
    if (specs.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _KpiTile(spec: specs[i])),
          ],
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final _KpiSpec spec;
  const _KpiTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final unavailable = spec.value == null;
    final warm = spec.attention && !unavailable && (spec.value ?? 0) > 0;
    final accent = unavailable ? AppColors.textTertiary : spec.accent;
    final shown = unavailable
        ? '—'
        : spec.approximate
            ? '${spec.value}+'
            : '${spec.value}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.openRoute(spec.route),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: warm ? AppColors.warningLight : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  unavailable ? Icons.cloud_off_outlined : spec.icon,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  shown,
                  style: AppTypography.kpiNumber.copyWith(
                    fontSize: 24,
                    color: warm ? AppColors.warningText : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec.label,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Data honesty: unavailable / stale
// ─────────────────────────────────────────────────────────────────────────

class _DataStatusBanner extends StatelessWidget {
  final DashboardData data;
  const _DataStatusBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final at = data.fetchedAt;
    final time = at == null
        ? ''
        : ' (données de ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')})';
    final text = data.stale
        ? 'Actualisation impossible : ces chiffres peuvent être périmés$time.'
        : 'Certaines données sont indisponibles. Les tirets ne sont pas des zéros.';
    return Container(
      key: const Key('dashboard-status-banner'),
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
          Expanded(child: Text(text, style: AppTypography.caption)),
          TextButton(
            onPressed: () => context.read<DashboardCubit>().load(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _UnavailableTile extends StatelessWidget {
  final String message;
  const _UnavailableTile({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_outlined,
            size: 18, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Attention tiles
// ─────────────────────────────────────────────────────────────────────────
