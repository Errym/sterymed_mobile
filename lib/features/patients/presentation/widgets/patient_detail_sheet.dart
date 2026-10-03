import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../prosthetic/data/models/prosthetic_case_data.dart';
import '../../../prosthetic/data/repositories/prosthetic_repository.dart';
import '../../../prosthetic/presentation/widgets/prosthetic_case_tile.dart';
import '../../../reporting/data/models/evidence_search_result_data.dart';
import '../../../reporting/data/repositories/evidence_search_repository.dart';
import '../../data/models/patient_data.dart';

/// Whether two patient references are the same patient (case and surrounding
/// spaces do not matter, a longer or shorter reference is someone else).
bool sameReference(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// A patient's file as the clinic can use it: their prosthetic work and the
/// sterile material that was used on them. The patient record itself is only a
/// reference, so everything useful here is what is linked to it, and each
/// section shows only for a role allowed to read it.
class PatientDetailSheet extends StatefulWidget {
  final PatientData patient;
  final bool canManage;
  final VoidCallback? onDelete;

  const PatientDetailSheet({
    super.key,
    required this.patient,
    required this.canManage,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required PatientData patient,
    required bool canManage,
    VoidCallback? onDelete,
  }) {
    return showAppSheet<void>(
      context,
      builder: (_) => PatientDetailSheet(
        patient: patient,
        canManage: canManage,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<PatientDetailSheet> createState() => _PatientDetailSheetState();
}

class _PatientDetailSheetState extends State<PatientDetailSheet> {
  Future<List<ProstheticCaseData>>? _cases;
  Future<List<EvidenceSearchResultData>>? _uses;

  @override
  void initState() {
    super.initState();
    final session = getIt<SessionStore>();
    final ref = widget.patient.reference;
    // Both server filters match a *part* of the reference ("PAT-00001" also
    // finds "PAT-000010"), so what comes back is narrowed to this exact
    // patient: another patient's files must never appear in this one's sheet.
    if (ref.isNotEmpty && session.hasPermission('prosthetic_cases.view')) {
      _cases = getIt<ProstheticRepository>()
          .list(patientReference: ref)
          .then((p) => p.items.where((c) => sameReference(c.patientReference, ref)).toList());
    }
    if (ref.isNotEmpty && session.hasPermission('usages.view')) {
      _uses = getIt<EvidenceSearchRepository>()
          .search(patientReference: ref)
          .then((p) => p.items.where((u) => sameReference(u.patientReference, ref)).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return DetailSheet(
      children: [
        Row(
          children: [
            EntityMark.initials(p.initials),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DOSSIER PATIENT', style: AppTypography.eyebrow),
                  Text(
                    p.reference.isEmpty ? 'Dossier sans référence' : p.reference,
                    style: AppTypography.sectionTitle,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Dossier anonyme : seule une référence est enregistrée, aucune '
          'information personnelle.',
          style: AppTypography.caption,
        ),
        if (_cases != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _Section<List<ProstheticCaseData>>(
            future: _cases!,
            title: 'DOSSIERS PROTHÉTIQUES',
            emptyText: 'Aucun dossier prothétique pour ce patient.',
            isEmpty: (c) => c.isEmpty,
            builder: (cases) => Column(
              children: [
                for (final c in cases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ProstheticCaseTile(
                      item: c,
                      onTap: () => _open(context, Routes.prostheticDetail(c.id)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_uses != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Section<List<EvidenceSearchResultData>>(
            future: _uses!,
            title: 'MATÉRIEL STÉRILE UTILISÉ',
            emptyText: 'Aucune utilisation de matériel stérile enregistrée.',
            isEmpty: (u) => u.isEmpty,
            builder: (uses) => Column(
              children: [
                for (final u in uses.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _UseRow(use: u),
                  ),
                if (uses.length > 10)
                  Text(
                    '+ ${uses.length - 10} autres dans la recherche de preuves',
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
        ],
        if (widget.canManage && widget.onDelete != null) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Supprimer ce dossier'),
          ),
        ],
      ],
    );
  }

  void _open(BuildContext sheetContext, String route) {
    // The router is taken before the sheet closes: its context is gone after.
    final router = GoRouter.of(sheetContext);
    Navigator.of(sheetContext).pop();
    if (isTabRoute(route)) {
      router.go(route);
    } else {
      router.push(route);
    }
  }
}

/// A titled block that loads on its own: a spinner, then the content, an
/// honest "could not load" or a calm empty line. One section failing never
/// blanks the rest of the sheet.
class _Section<T> extends StatelessWidget {
  final Future<T> future;
  final String title;
  final String emptyText;
  final bool Function(T) isEmpty;
  final Widget Function(T) builder;

  const _Section({
    required this.future,
    required this.title,
    required this.emptyText,
    required this.isEmpty,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<T>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snap.hasError) {
              return const Text(
                'Impossible de charger cette section.',
                style: AppTypography.caption,
              );
            }
            final data = snap.data as T;
            if (isEmpty(data)) {
              return Text(emptyText, style: AppTypography.caption);
            }
            return builder(data);
          },
        ),
      ],
    );
  }
}

class _UseRow extends StatelessWidget {
  final EvidenceSearchResultData use;
  const _UseRow({required this.use});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  use.procedure.isEmpty ? 'Utilisation' : use.procedure,
                  style: AppTypography.bodyStrong,
                ),
              ),
              TypeBadge(
                label: AppDateFormatter.date(use.usedAt.toLocal()),
                tone: BadgeTone.gray,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              InfoTag('Cycle #${use.cycleNumber}', icon: Icons.autorenew),
              if (use.deviceName.isNotEmpty)
                InfoTag(use.deviceName, icon: Icons.precision_manufacturing_outlined),
              if ((use.batchNumber ?? '').isNotEmpty)
                InfoTag('Lot ${use.batchNumber}', icon: Icons.qr_code_2),
              if (use.practitionerName.isNotEmpty)
                InfoTag(use.practitionerName, icon: Icons.person_outline),
            ],
          ),
        ],
      ),
    );
  }
}
