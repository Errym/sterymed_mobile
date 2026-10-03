import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/repositories/cycle_repository.dart';

/// Full-screen view of one cycle attachment: a zoomable image, or a PDF
/// handed to the device's PDF reader. Whoever may read the cycle (a releaser
/// signing it off, for instance) can open the evidence.
///
/// The link the server returns is short-lived and signed, so when it no longer
/// works the viewer asks the server for a fresh one instead of showing a dead
/// picture; a failure is stated, never rendered as an empty file.
class AttachmentViewerScreen extends StatefulWidget {
  final String? cycleId;
  final CycleAttachmentData attachment;

  /// Re-reads the owner's attachment list to get a fresh signed link. Defaults
  /// to the cycle's list; other owners (a goods receipt) pass their own.
  final Future<List<CycleAttachmentData>> Function()? reload;

  const AttachmentViewerScreen({
    super.key,
    this.cycleId,
    required this.attachment,
    this.reload,
  }) : assert(
         cycleId != null || reload != null,
         'Give a cycleId or a reload function to refresh the link.',
       );

  static Future<void> open(
    BuildContext context, {
    String? cycleId,
    required CycleAttachmentData attachment,
    Future<List<CycleAttachmentData>> Function()? reload,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentViewerScreen(
          cycleId: cycleId,
          attachment: attachment,
          reload: reload,
        ),
      ),
    );
  }

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  late CycleAttachmentData _current = widget.attachment;
  bool _refreshing = false;
  bool _opening = false;
  String? _error;
  int _imageKey = 0;

  /// Re-reads the attachment list to obtain a new signed link.
  Future<void> _refreshLink() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final reload = widget.reload;
      final all = reload != null
          ? await reload()
          : await getIt<CycleRepository>().listAttachments(widget.cycleId!);
      final fresh = all.where((a) => a.id == _current.id);
      if (!mounted) return;
      if (fresh.isEmpty) {
        setState(() {
          _refreshing = false;
          _error = 'Cette pièce jointe n\'existe plus.';
        });
        return;
      }
      setState(() {
        _current = fresh.first;
        _imageKey++;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  Future<void> _openPdf() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final name = (_current.fileName ?? 'piece-jointe.pdf').replaceAll(
        RegExp(r'[^\w.\-]'),
        '_',
      );
      final path = '${Directory.systemTemp.path}/$name';
      await Dio().download(MediaUrl.resolve(_current.url), path);
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        setState(
          () => _error =
              'Aucune application ne peut ouvrir ce PDF sur cet '
              'appareil.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      // The link may simply have expired: get a fresh one for the next try.
      setState(() => _error = 'Impossible de télécharger le fichier.');
      await _refreshLink();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _current;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(title: a.fileName ?? 'Pièce jointe'),
      body: _refreshing
          ? const Center(child: CircularProgressIndicator())
          : a.isImage
          ? _image(a)
          : _document(a),
    );
  }

  Widget _image(CycleAttachmentData a) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5,
      child: Center(
        child: Image.network(
          MediaUrl.resolve(a.url),
          key: ValueKey(_imageKey),
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => _Failure(
            message:
                _error ??
                'Impossible d\'afficher l\'image (lien expiré ou réseau '
                    'indisponible).',
            onRetry: _refreshLink,
          ),
        ),
      ),
    );
  }

  Widget _document(CycleAttachmentData a) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              a.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              size: 56,
              color: a.isPdf ? AppColors.danger : AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(a.fileName ?? 'Pièce jointe', textAlign: TextAlign.center),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _opening ? null : _openPdf,
              icon: _opening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ouvrir le fichier'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Failure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
