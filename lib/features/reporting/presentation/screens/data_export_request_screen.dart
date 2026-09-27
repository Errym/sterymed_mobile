import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
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
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _download(ExportRequestData export) async {
    try {
      final url = await getIt<ExportRepository>().downloadUrl(export.id);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Lien copié — ouvrez-le dans un navigateur pour télécharger.',
        kind: SnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
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
                      _ExportCard(export: e, onDownload: () => _download(e)),
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

  const _ExportCard({required this.export, required this.onDownload});

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
              onPressed: onDownload,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Copier le lien de l\'archive ZIP'),
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
