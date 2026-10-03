import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../widgets/cycle_attachment_grid.dart';
import 'attachment_viewer_screen.dart';

class CycleAttachmentsScreen extends StatefulWidget {
  final String cycleId;
  const CycleAttachmentsScreen({super.key, required this.cycleId});

  @override
  State<CycleAttachmentsScreen> createState() => _CycleAttachmentsScreenState();
}

class _PendingUpload {
  final String name;
  final Uint8List bytes;
  final String? mimeType;
  const _PendingUpload(this.name, this.bytes, this.mimeType);
}

class _CycleAttachmentsScreenState extends State<CycleAttachmentsScreen> {
  List<CycleAttachmentData> _attachments = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  bool get _canManage => getIt<SessionStore>().hasPermission('cycles.manage');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await getIt<CycleRepository>().listAttachments(
        widget.cycleId,
      );
      if (!mounted) return;
      setState(() {
        _attachments = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  /// The photo (or file) that could not be sent, kept so "Réessayer" does not
  /// ask the user to take it again.
  _PendingUpload? _failed;
  double? _progress;

  Future<void> _add() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    await _send(_PendingUpload(file.name, bytes, file.mimeType));
  }

  Future<void> _send(_PendingUpload upload) async {
    setState(() {
      _uploading = true;
      _failed = null;
      _progress = 0;
    });
    try {
      await getIt<CycleRepository>().uploadAttachment(
        cycleId: widget.cycleId,
        fileName: upload.name,
        bytes: upload.bytes,
        mimeType: upload.mimeType,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Photo ajoutée.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _failed = upload);
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _delete(CycleAttachmentData a) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cette pièce jointe ?',
      message: a.fileName ?? 'Pièce jointe',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await getIt<CycleRepository>().deleteAttachment(widget.cycleId, a.id);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Pièce jointe supprimée.',
        kind: SnackKind.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Pièces jointes'),
      body: Column(
        children: [
          if (_uploading) LinearProgressIndicator(value: _progress),
          if (_failed != null)
            MaterialBanner(
              content: const Text(
                'L\'envoi a échoué. La photo est conservée : réessayez.',
              ),
              actions: [
                TextButton(
                  onPressed: _uploading ? null : () => _send(_failed!),
                  child: const Text('Réessayer'),
                ),
                TextButton(
                  onPressed: () => setState(() => _failed = null),
                  child: const Text('Abandonner'),
                ),
              ],
            ),
          Expanded(child: _content(canManage)),
        ],
      ),
      floatingActionButton: canManage && _attachments.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _add,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }

  Widget _content(bool canManage) {
    return _loading && _attachments.isEmpty
        ? const LoadingView()
        : _error != null && _attachments.isEmpty
        ? ErrorView(message: _error!, onRetry: _load)
        : _attachments.isEmpty
        ? EmptyView(
            title: 'Aucune pièce jointe',
            message: canManage
                ? 'Ajoutez une photo pour ce cycle.'
                : 'Aucune photo n\'a été ajoutée pour ce cycle.',
            icon: Icons.attach_file,
          )
        : Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: CycleAttachmentGrid(
              attachments: _attachments,
              onAdd: canManage && !_uploading ? _add : null,
              onOpen: (a) => AttachmentViewerScreen.open(
                context,
                cycleId: widget.cycleId,
                attachment: a,
              ),
              onDelete: canManage ? _delete : null,
            ),
          );
  }
}
