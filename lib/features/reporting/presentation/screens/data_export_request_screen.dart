import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';

class DataExportRequestScreen extends StatelessWidget {
  const DataExportRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Export & Portabilité des Données'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Main archive card
          Container(
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
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.download_outlined,
                        size: 18,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'Archive Réglementaire Complète',
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Conformément aux exigences de traçabilité ARS et RGPD, '
                  'cet export compile l\'intégralité des cycles d\'autoclaves, '
                  'fiches de traçabilité patients, mouvements de stocks et '
                  'justificatifs scannés dans une archive ZIP sécurisée.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Demander un Export Complet (ZIP)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'HISTORIQUE DES EXPORTS GÉNÉRÉS',
            style: AppTypography.label.copyWith(
              letterSpacing: 0.6,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ExportCard(
            reference: 'EXP-2026-08-30-01',
            date: 'Demandé le 15/09/2026 20:38 par Direction Cabinet (Owner)',
            size: 'Taille : 13.9 Mo · Format ZIP standard (données + PDFs)',
            status: 'Disponible',
            statusTone: BadgeTone.green,
            hasDownload: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ExportCard(
            reference: 'EXP-2026-08-15-02',
            date: 'Demandé le 31/08/2026 23:38 par Direction Cabinet (Owner)',
            size: 'Taille : 12.5 Mo · Format ZIP standard (données + PDFs)',
            status: 'Expiré (7j)',
            statusTone: BadgeTone.gray,
            hasDownload: false,
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final String reference;
  final String date;
  final String size;
  final String status;
  final BadgeTone statusTone;
  final bool hasDownload;

  const _ExportCard({
    required this.reference,
    required this.date,
    required this.size,
    required this.status,
    required this.statusTone,
    required this.hasDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const Icon(
                Icons.folder_zip_outlined,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(reference, style: AppTypography.bodyStrong),
              ),
              TypeBadge(label: status, tone: statusTone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(date, style: AppTypography.caption),
          const SizedBox(height: 2),
          Text(size, style: AppTypography.caption),
          if (hasDownload) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Télécharger l\'archive ZIP'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                side: const BorderSide(color: AppColors.brandPrimary),
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
