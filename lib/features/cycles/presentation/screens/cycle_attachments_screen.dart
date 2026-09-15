import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../data/models/cycle_attachment_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../widgets/cycle_attachment_grid.dart';
class CycleAttachmentsScreen extends StatefulWidget {
  final String cycleId;
  const CycleAttachmentsScreen({super.key, required this.cycleId});

  @override
  State<CycleAttachmentsScreen> createState() => _CycleAttachmentsScreenState();
}

class _CycleAttachmentsScreenState extends State<CycleAttachmentsScreen> {
  List<CycleAttachmentData> _attachments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items =
          await context.read<CycleRepository>().listAttachments(widget.cycleId);
      if (!mounted) return;
      setState(() {
        _attachments = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    try {
      await context.read<CycleRepository>().uploadAttachment(
            widget.cycleId,
            file.path,
            file.name,
          );
      if (!mounted) return;
      AppSnackbar.show(context, 'Fichier ajouté.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  Future<void> _delete(CycleAttachmentData a) async {
    try {
      await context
          .read<CycleRepository>()
          .deleteAttachment(widget.cycleId, a.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Pièces jointes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attachments.isEmpty
              ? const EmptyView(
                  title: 'Aucune pièce jointe',
                  message: 'Ajoutez une photo ou un document.',
                  icon: Icons.attach_file,
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: CycleAttachmentGrid(
                    attachments: _attachments,
                    onAdd: _add,
                    onDelete: _delete,
                  ),
                ),
      floatingActionButton: _attachments.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }
}
