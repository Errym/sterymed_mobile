import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/prosthetic_case_attachment_data.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/models/prosthetic_case_status_history_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../widgets/prosthetic_case_edit_sheet.dart';
import '../widgets/prosthetic_case_tile.dart';
import '../widgets/prosthetic_payment_section.dart';

class ProstheticCaseDetailScreen extends StatefulWidget {
  final String caseId;
  const ProstheticCaseDetailScreen({super.key, required this.caseId});

  @override
  State<ProstheticCaseDetailScreen> createState() =>
      _ProstheticCaseDetailScreenState();
}

class _ProstheticCaseDetailScreenState
    extends State<ProstheticCaseDetailScreen> {
  ProstheticCaseData? _case;
  List<ProstheticCaseStatusHistoryData> _history = [];
  List<ProstheticCaseAttachmentData> _attachments = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _canManageClinical =>
      getIt<SessionStore>().hasPermission('prosthetic_cases.manage');
  bool get _canManagePayments =>
      getIt<SessionStore>().hasPermission('prosthetic_payments.manage');

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
      final repo = getIt<ProstheticRepository>();
      final results = await Future.wait([
        repo.show(widget.caseId),
        repo.statusHistory(widget.caseId),
        repo.listAttachments(widget.caseId),
      ]);
      if (!mounted) return;
      setState(() {
        _case = results[0] as ProstheticCaseData;
        _history = results[1] as List<ProstheticCaseStatusHistoryData>;
        _attachments = results[2] as List<ProstheticCaseAttachmentData>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessage.from(e);
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(ProstheticCaseStatus to) async {
    final critical = to == ProstheticCaseStatus.placed ||
        to == ProstheticCaseStatus.cancelled;
    String? note;

    if (critical) {
      final noteCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(to == ProstheticCaseStatus.placed
              ? 'Confirmer la pose ?'
              : 'Annuler ce dossier ?'),
          content: AppTextArea(
            label: 'Note (optionnel)',
            controller: noteCtrl,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      note = noteCtrl.text.trim();
    }

    setState(() => _busy = true);
    try {
      await getIt<ProstheticRepository>().changeStatus(
        widget.caseId,
        status: to.wire,
        note: (note != null && note.isNotEmpty) ? note : null,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Statut mis à jour.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAttachment() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      await getIt<ProstheticRepository>().uploadAttachment(
        caseId: widget.caseId,
        fileName: file.name,
        bytes: bytes,
        mimeType: file.mimeType,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Photo ajoutée.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAttachment(ProstheticCaseAttachmentData a) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cette pièce jointe ?',
      message: a.fileName ?? 'Pièce jointe',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await getIt<ProstheticRepository>()
          .deleteAttachment(widget.caseId, a.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Pièce jointe supprimée.',
          kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _editCase() async {
    final saved = await ProstheticCaseEditSheet.show(context, _case!);
    if (saved == true) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Dossier mis à jour.', kind: SnackKind.success);
      await _load();
    }
  }

  Future<void> _savePaymentFields(Map<String, dynamic> data) async {
    setState(() => _busy = true);
    try {
      await getIt<ProstheticRepository>().update(widget.caseId, data);
      if (!mounted) return;
      AppSnackbar.show(context, 'Informations de paiement enregistrées.',
          kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Dossier prothétique',
        actions: [
          if (!_loading && _error == null && _case != null && _canManageClinical)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: _busy ? null : _editCase,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final c = _case!;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.patientReference,
                    style: AppTypography.pageTitle),
              ),
              TypeBadge(
                label: c.status.label,
                tone: prostheticStatusTone(c.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (c.status.allowedNext.isNotEmpty && _canManageClinical) ...[
            const SectionHeader(title: 'Changer le statut'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: c.status.allowedNext
                  .map((s) => OutlinedButton(
                        onPressed: _busy ? null : () => _changeStatus(s),
                        child: Text(s.label),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          const SectionHeader(title: 'Informations cliniques'),
          _InfoCard(rows: [
            ('Praticien', c.practitionerName),
            ('Type d\'empreinte', c.impressionType.label),
            ('Type de travail', c.workType.label),
            ('Date d\'empreinte', dateFmt.format(c.impressionDate)),
            if (c.laboratoryName != null) ('Laboratoire', c.laboratoryName!),
            if (c.sentToLabDate != null)
              ('Envoyé le', dateFmt.format(c.sentToLabDate!)),
            if (c.returnedFromLabDate != null)
              ('Reçu le', dateFmt.format(c.returnedFromLabDate!)),
            if (c.plannedPlacementDate != null)
              ('Pose prévue', dateFmt.format(c.plannedPlacementDate!)),
            if (c.actualPlacementDate != null)
              ('Posé le', dateFmt.format(c.actualPlacementDate!)),
            if (c.priority != null) ('Priorité', c.priority!),
          ]),
          if (c.notes != null && c.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _NoteBlock(label: 'Remarques', text: c.notes!),
          ],
          if (_canManageClinical &&
              c.internalComments != null &&
              c.internalComments!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _NoteBlock(label: 'Commentaires internes', text: c.internalComments!),
          ],

          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Administratif & paiement'),
          ProstheticPaymentSection(
            data: c,
            canEdit: _canManagePayments,
            busy: _busy,
            onSave: _savePaymentFields,
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Pièces jointes',
            trailing: _canManageClinical
                ? IconButton(
                    icon: const Icon(Icons.add_a_photo_outlined),
                    onPressed: _busy ? null : _addAttachment,
                  )
                : null,
          ),
          if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Aucune pièce jointe.', style: AppTypography.caption),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _attachments
                  .map((a) => _AttachmentChip(
                        attachment: a,
                        onDelete: _canManageClinical
                            ? () => _deleteAttachment(a)
                            : null,
                      ))
                  .toList(),
            ),

          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Historique'),
          for (final h in _history) _HistoryTile(history: h, dateFmt: dateFmt),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(rows[i].$1, style: AppTypography.label),
                  ),
                  Text(rows[i].$2, style: AppTypography.bodyStrong),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.borderLight),
          ],
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String label;
  final String text;
  const _NoteBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 4),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final ProstheticCaseAttachmentData attachment;
  final VoidCallback? onDelete;
  const _AttachmentChip({required this.attachment, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        attachment.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
        size: 18,
      ),
      label: Text(attachment.fileName ?? 'Fichier',
          overflow: TextOverflow.ellipsis),
      onDeleted: onDelete,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ProstheticCaseStatusHistoryData history;
  final DateFormat dateFmt;
  const _HistoryTile({required this.history, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final to = ProstheticCaseStatus.fromWire(history.toStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.brandPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(to.label, style: AppTypography.bodyStrong),
                Text(
                  '${dateFmt.format(history.createdAt)} · ${history.changedByName}',
                  style: AppTypography.caption,
                ),
                if (history.note != null && history.note!.isNotEmpty)
                  Text(history.note!, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
