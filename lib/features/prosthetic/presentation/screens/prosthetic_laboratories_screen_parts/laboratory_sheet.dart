part of '../prosthetic_laboratories_screen.dart';

enum _LabAction { edit, archive }

/// Everything about one laboratory: its numbers, how to reach it, and its most
/// recent cases (each opens the case).
class _LaboratorySheet extends StatelessWidget {
  final LaboratoryData lab;
  final Future<LaboratoryStats> stats;
  final ProstheticRepository repo;
  final bool canManage;

  const _LaboratorySheet({
    required this.lab,
    required this.stats,
    required this.repo,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if ((lab.contactName ?? '').isNotEmpty)
        DetailRow(Icons.person_outline, 'Contact', lab.contactName!),
      if ((lab.contactPhone ?? '').isNotEmpty)
        DetailRow(Icons.call_outlined, 'Téléphone', lab.contactPhone!),
      if ((lab.contactEmail ?? '').isNotEmpty)
        DetailRow(Icons.mail_outline, 'E-mail', lab.contactEmail!),
      if ((lab.address ?? '').isNotEmpty)
        DetailRow(Icons.place_outlined, 'Adresse', lab.address!),
    ];
    return DetailSheet(
      children: [
        Row(
          children: [
            EntityMark.initials(EntityMark.initialsOf(lab.name)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LABORATOIRE PARTENAIRE', style: AppTypography.eyebrow),
                  Text(lab.name, style: AppTypography.sectionTitle),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SheetStats(stats: stats),
        const SizedBox(height: AppSpacing.md),
        if (rows.isEmpty)
          const Text(
            'Aucun contact enregistré. Ajoutez un téléphone ou un e-mail '
            'pour pouvoir appeler ou écrire en un geste.',
            style: AppTypography.caption,
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceWell,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(children: rows),
          ),
          const SizedBox(height: AppSpacing.sm),
          ContactActions(
            phone: lab.contactPhone,
            email: lab.contactEmail,
            address: lab.address,
          ),
        ],
        if ((lab.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('REMARQUES', style: AppTypography.eyebrow),
          const SizedBox(height: 2),
          Text(lab.notes!, style: AppTypography.body),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Text('DERNIERS TRAVAUX', style: AppTypography.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        _RecentCases(repo: repo, laboratoryId: lab.id),
        if (canManage) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('lab-edit'),
                  onPressed: () => Navigator.of(context).pop(_LabAction.edit),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('lab-archive'),
                  onPressed: () => Navigator.of(context).pop(_LabAction.archive),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Archiver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SheetStats extends StatelessWidget {
  final Future<LaboratoryStats> stats;
  const _SheetStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LaboratoryStats>(
      future: stats,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return const NoteStrip(
            key: Key('lab-sheet-stats-unavailable'),
            text: 'Les chiffres de ce laboratoire sont indisponibles pour '
                'le moment.',
            icon: Icons.cloud_off_outlined,
          );
        }
        final s = snap.data!;
        Widget tile(String value, String label, {Color? color}) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Column(
                  children: [
                    Text(
                      value,
                      style: AppTypography.kpiNumber.copyWith(
                        fontSize: 22,
                        color: color ?? AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
        return Column(
          key: const Key('lab-sheet-stats'),
          children: [
            Row(
              children: [
                tile('${s.atLaboratory}', 'Chez le labo'),
                const SizedBox(width: AppSpacing.xs),
                tile(
                  '${s.waitingForPlacement}',
                  'À poser',
                  color: s.hasUrgent ? AppColors.danger : null,
                ),
                const SizedBox(width: AppSpacing.xs),
                tile('${s.total}', 'Au total'),
              ],
            ),
            if (s.waitingForPlacement > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Attente de pose : ${s.fresh} de 0 à 7 j · ${s.medium} de 8 à '
                '14 j · ${s.urgent} de 15 j et plus',
                key: const Key('lab-aging'),
                style: AppTypography.caption,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RecentCases extends StatefulWidget {
  final ProstheticRepository repo;
  final String laboratoryId;
  const _RecentCases({required this.repo, required this.laboratoryId});

  @override
  State<_RecentCases> createState() => _RecentCasesState();
}

class _RecentCasesState extends State<_RecentCases> {
  late final Future<CursorPageCases> _future = widget.repo
      .list(laboratoryId: widget.laboratoryId)
      .then((page) => page.items.take(5).toList());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CursorPageCases>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return const Text('Travaux indisponibles.', style: AppTypography.caption);
        }
        final cases = snap.data ?? const <ProstheticCaseData>[];
        if (cases.isEmpty) {
          return const Text(
            'Aucun travail confié à ce laboratoire.',
            key: Key('lab-no-cases'),
            style: AppTypography.caption,
          );
        }
        return Column(
          key: const Key('lab-recent-cases'),
          children: [
            for (final c in cases)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ProstheticCaseTile(
                  item: c,
                  onTap: () {
                    // Captured before the sheet closes: its context is gone after.
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(Routes.prostheticDetail(c.id));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

typedef CursorPageCases = List<ProstheticCaseData>;
