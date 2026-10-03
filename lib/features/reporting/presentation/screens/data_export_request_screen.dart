import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/files/file_export_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/feedback/saved_file_sheet.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/export_request_data.dart';
import '../../data/repositories/export_repository.dart';

class DataExportRequestScreen extends StatefulWidget {
  const DataExportRequestScreen({super.key});

  @override
  State<DataExportRequestScreen> createState() =>
      _DataExportRequestScreenState();
}

class _DataExportRequestScreenState extends State<DataExportRequestScreen> {
  late Future<List<ExportRequestData>> _future;
  bool _requesting = false;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = getIt<ExportRepository>().list(forceRefresh: true);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _requestExport() async {
    setState(() => _requesting = true);
    try {
      await getIt<ExportRepository>().request();
      if (!mounted) return;
      AppSnackbar.show(context, 'Export demandé.', kind: SnackKind.success);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _download(ExportRequestData export) async {
    try {
      setState(() => _downloadingId = export.id);
      final url = await getIt<ExportRepository>().downloadUrl(export.id);
      if (!mounted) return;
      final file = await getIt<FileExportService>().saveFromUrl(
        url,
        baseName: 'steriymed-export-${export.id.substring(0, 8)}',
        extension: 'zip',
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Téléchargement terminé.',
        kind: SnackKind.success,
      );
      // The download is over: the button must not keep spinning behind the sheet.
      setState(() => _downloadingId = null);
      await SavedFileSheet.show(
        context,
        file: file,
        title: 'Archive enregistrée',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Export & Portabilité des Données'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Main archive card
            AppCard(
              key: const Key('export-request-card'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      EntityMark.icon(Icons.folder_zip_outlined),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ARCHIVE COMPLÈTE', style: AppTypography.eyebrow),
                            Text('Export du cabinet', style: AppTypography.cardTitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Pour un contrôle (ARS), une demande de portabilité ou une '
                    'sauvegarde : tout ce que le cabinet a enregistré, dans une '
                    'archive ZIP.',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    key: const Key('export-contents'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWell,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CONTENU', style: AppTypography.eyebrow),
                        SizedBox(height: AppSpacing.xs),
                        DetailRow(Icons.autorenew, 'Cycles', 'et leurs contrôles'),
                        DetailRow(Icons.qr_code_2, 'Étiquettes', 'et utilisations'),
                        DetailRow(Icons.swap_vert, 'Stock', 'mouvements et lots'),
                        DetailRow(Icons.attach_file, 'Pièces jointes', 'avec empreinte SHA-256'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const NoteStrip(
                    key: Key('export-rules'),
                    text: 'Un export à la fois, 5 par semaine au maximum. '
                        'Chaque archive reste disponible 7 jours.',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _requesting ? null : _requestExport,
                    icon: _requesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
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
            FutureBuilder<List<ExportRequestData>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: LoadingView(),
                  );
                }
                if (snap.hasError) {
                  return ErrorView(
                    message: 'Impossible de charger l\'historique.',
                    onRetry: _refresh,
                  );
                }
                final exports = snap.data ?? const [];
                if (exports.isEmpty) {
                  return const EmptyView(
                    title: 'Aucun export généré',
                    message: 'Les exports demandés apparaîtront ici.',
                    icon: Icons.folder_zip_outlined,
                  );
                }
                return Column(
                  children: [
                    for (final e in exports) ...[
                      _ExportCard(
                        export: e,
                        onDownload: () => _download(e),
                        downloading: _downloadingId == e.id,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final ExportRequestData export;
  final VoidCallback onDownload;
  final bool downloading;

  const _ExportCard({
    required this.export,
    required this.onDownload,
    this.downloading = false,
  });

  String get _statusLabel => switch (export.status) {
        'completed' => 'Disponible',
        'expired' => 'Expiré',
        'pending' => 'En préparation',
        'processing' => 'En préparation',
        'failed' => 'Échec',
        _ => export.status,
      };

  BadgeTone get _statusTone => switch (export.status) {
        'completed' => BadgeTone.green,
        'expired' => BadgeTone.gray,
        'failed' => BadgeTone.red,
        _ => BadgeTone.orange,
      };

  String get _sizeLabel {
    final bytes = export.sizeBytes;
    if (bytes == null) return '';
    final mb = bytes / (1024 * 1024);
    return 'Taille : ${mb.toStringAsFixed(1)} Mo';
  }

  String get _countsLabel {
    final parts = <String>[];
    if (export.recordCount != null) {
      parts.add('${export.recordCount} enregistrements');
    }
    if (export.fileCount != null) {
      parts.add('${export.fileCount} fichiers');
    }
    return parts.join(' · ');
  }

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
          Row(
            children: [
              const Icon(
                Icons.folder_zip_outlined,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Export du '
                  '${DateFormat('dd/MM/yyyy').format(export.requestedAt)}',
                  style: AppTypography.bodyStrong,
                ),
              ),
              TypeBadge(label: _statusLabel, tone: _statusTone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Demandé le '
            '${DateFormat('dd/MM/yyyy HH:mm').format(export.requestedAt)}'
            '${export.requestedByName.isNotEmpty ? ' par ${export.requestedByName}' : ''}',
            style: AppTypography.caption,
          ),
          if (_sizeLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_sizeLabel, style: AppTypography.caption),
          ],
          if (_countsLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_countsLabel, style: AppTypography.caption),
          ],
          if (export.isFailed && export.error != null) ...[
            const SizedBox(height: 2),
            Text(
              export.error!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          if (export.isCompleted) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: downloading ? null : onDownload,
              icon: downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : const Icon(Icons.download, size: 16),
              label: Text(
                downloading
                    ? 'Téléchargement…'
                    : 'Télécharger l\'archive ZIP',
              ),
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
