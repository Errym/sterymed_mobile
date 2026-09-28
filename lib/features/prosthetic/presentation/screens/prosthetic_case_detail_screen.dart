import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/prosthetic_case_attachment_data.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/models/prosthetic_case_status_history_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../utils/prosthetic_case_pdf.dart';
import '../widgets/prosthetic_attachment_chip.dart';
import '../widgets/prosthetic_case_edit_sheet.dart';
import '../widgets/prosthetic_case_tile.dart';
import '../widgets/prosthetic_history_tile.dart';
import '../widgets/prosthetic_info_card.dart';
import '../widgets/prosthetic_note_block.dart';
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

    final noteCtrl = TextEditingController();
    try {
      if (critical) {
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
        AppSnackbar.show(context, 'Statut mis à jour.',
            kind: SnackKind.success);
        await _load();
      } catch (e) {
        if (!mounted) return;
        AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } finally {
      noteCtrl.dispose();
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
      await getIt<ProstheticRepository>().deleteAttachment(widget.caseId, a.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Pièce jointe supprimée.',
          kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Future<void> _printCase() async {
    final c = _case;
    if (c == null) return;
    await Printing.layoutPdf(
      onLayout: (_) => buildProstheticCasePdf(c),
      name: 'Dossier prothétique — ${c.patientReference}',
    );
  }

   Future<void> _editCase() async {
    final current = _case;
    if (current == null) return;
    final saved = await ProstheticCaseEditSheet.show(context, current);
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
          if (!_loading && _error == null && _case != null)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimer / Exporter en PDF',
              onPressed: _printCase,
            ),
          if (!_loading &&
              _error == null &&
              _case != null &&
              _canManageClinical)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: _busy ? null : _editCase,
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

   Widget _buildBody() {
    final c = _case;
    if (c == null) {
      return const SizedBox.shrink();
    }
    final dateFmt = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.patientReference, style: AppTypography.pageTitle),
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
          ProstheticInfoCard(rows: [
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
            ProstheticNoteBlock(label: 'Remarques', text: c.notes!),
          ],
          if (_canManageClinical &&
              c.internalComments != null &&
              c.internalComments!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ProstheticNoteBlock(
                label: 'Commentaires internes', text: c.internalComments!),
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
                  .map((a) => ProstheticAttachmentChip(
                        attachment: a,
                        onDelete: _canManageClinical
                            ? () => _deleteAttachment(a)
                            : null,
                      ))
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Historique'),
          for (final h in _history)
            ProstheticHistoryTile(history: h, dateFmt: dateFmt),
        ],
      ),
    );
  }
}
