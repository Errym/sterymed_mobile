import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/permissions/camera_permission.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../widgets/cycle_attachment_grid.dart';

class CycleAttachmentsScreen extends StatefulWidget {
  final String cycleId;
  const CycleAttachmentsScreen({super.key, required this.cycleId});

  @override
  State<CycleAttachmentsScreen> createState() =>
      _CycleAttachmentsScreenState();
}

class _CycleAttachmentsScreenState extends State<CycleAttachmentsScreen> {
  List<CycleAttachmentData> _attachments = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<CycleRepository>();
      final items = await repo.listAttachments(widget.cycleId);
      if (!mounted) return;
      setState(() {
        _attachments = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _pickFromCamera() async {
    final granted = await CameraPermission.request();
    if (!mounted) return;
    if (!granted) {
      final permanentlyDenied = await CameraPermission.isPermanentlyDenied();
      if (!mounted) return;
      if (permanentlyDenied) {
        _showOpenSettings();
      } else {
        AppSnackbar.show(
          context,
          'Autorisation caméra refusée.',
          kind: SnackKind.warning,
        );
      }
      return;
    }
    await _pick(ImageSource.camera);
  }

  Future<void> _pickFromGallery() async {
    await _pick(ImageSource.gallery);
  }

  void _showOpenSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Autorisation caméra'),
        content: const Text(
          'L\'accès à la caméra est bloqué. Ouvrez les paramètres pour '
          'l\'autoriser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              CameraPermission.openSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 2000,
      );
      if (file == null || !mounted) return;

      setState(() => _uploading = true);

      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? _mimeFromName(file.name);

      if (!mounted) return;
      final repo = context.read<CycleRepository>();
      await repo.uploadAttachment(
        cycleId: widget.cycleId,
        fileName: file.name,
        bytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Fichier ajouté.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  Future<void> _delete(CycleAttachmentData a) async {
    try {
      final repo = context.read<CycleRepository>();
      await repo.deleteAttachment(widget.cycleId, a.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _showPickerSheet() async {
    if (kIsWeb) {
      // Browsers expose camera + gallery through the same file input.
      await _pickFromGallery();
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text(
                'Annuler',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.brandPrimary),
              ),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'camera') await _pickFromCamera();
    if (choice == 'gallery') await _pickFromGallery();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Pièces jointes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attachments.isEmpty
              ? EmptyView(
                  title: 'Aucune pièce jointe',
                  message: 'Ajoutez une photo ou un document.',
                  icon: Icons.attach_file,
                  action: FilledButton.icon(
                    onPressed: _uploading ? null : _showPickerSheet,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Ajouter un fichier'),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: CycleAttachmentGrid(
                    attachments: _attachments,
                    onAdd: _showPickerSheet,
                    onDelete: _delete,
                  ),
                ),
      floatingActionButton: _attachments.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _uploading ? null : _showPickerSheet,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_uploading ? 'Envoi…' : 'Ajouter'),
            ),
    );
  }
}
