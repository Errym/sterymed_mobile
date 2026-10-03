import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/media/photo_source.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../cycles/presentation/screens/attachment_viewer_screen.dart';
import '../../data/models/goods_receipt_data.dart';
import '../../data/repositories/purchase_repository.dart';

/// Every delivery received against an order: when, by whom, where it was put,
/// which lots came in, and whether the delivery note was photographed.
///
/// A receipt without a photo is shown as a task ("justificatif manquant")
/// that can be completed here, instead of being forgotten.
class ReceiptHistorySection extends StatefulWidget {
  final String poId;
  final bool canAddProof;
  final PhotoPicker? photoPicker;

  const ReceiptHistorySection({
    super.key,
    required this.poId,
    required this.canAddProof,
    this.photoPicker,
  });

  @override
  State<ReceiptHistorySection> createState() => _ReceiptHistorySectionState();
}

class _ReceiptHistorySectionState extends State<ReceiptHistorySection> {
  List<GoodsReceiptData>? _receipts;
  String? _error;
  bool _loading = true;
  String? _uploadingId;
  double? _progress;

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
      final receipts = await getIt<PurchaseRepository>().receipts(widget.poId);
      if (!mounted) return;
      setState(() {
        _receipts = receipts;
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

  Future<void> _addProof(GoodsReceiptData receipt) async {
    final picker = widget.photoPicker ?? PhotoSource.choose;
    final photo = await picker(context);
    if (photo == null || !mounted) return;
    setState(() {
      _uploadingId = receipt.id;
      _progress = 0;
    });
    try {
      await getIt<PurchaseRepository>().uploadReceiptProof(
        receiptId: receipt.id,
        fileName: photo.name,
        bytes: photo.bytes,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Justificatif ajouté.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _uploadingId = null);
    }
  }

  Future<void> _openProof(GoodsReceiptData receipt) async {
    try {
      final files = await getIt<PurchaseRepository>().receiptAttachments(
        receipt.id,
      );
      if (!mounted) return;
      if (files.isEmpty) {
        AppSnackbar.show(
          context,
          'Aucun justificatif sur cette réception.',
          kind: SnackKind.warning,
        );
        return;
      }
      await AttachmentViewerScreen.open(
        context,
        attachment: files.first,
        reload: () => getIt<PurchaseRepository>().receiptAttachments(receipt.id),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Historique des réceptions indisponible : $_error',
                style: AppTypography.caption,
              ),
            ),
            TextButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    final receipts = _receipts ?? const [];
    if (receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('Aucune réception enregistrée.', style: AppTypography.caption),
      );
    }
    return Column(
      children: [for (final r in receipts) _tile(r)],
    );
  }

  Widget _tile(GoodsReceiptData r) {
    final uploading = _uploadingId == r.id;
    return Container(
      key: ValueKey('receipt_${r.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(r.receivedAt.toLocal()),
                  style: AppTypography.bodyStrong,
                ),
              ),
              r.hasProof
                  ? const TypeBadge(label: 'Justificatif', tone: BadgeTone.green)
                  : const TypeBadge(
                      label: 'Justificatif manquant',
                      tone: BadgeTone.orange,
                    ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (r.receivedByName != null) 'Par ${r.receivedByName}',
              if (r.locationName != null) r.locationName!,
            ].join(' · '),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final l in r.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${l.productName}\nLot ${l.batchNumber}'
                      '${l.expiryDate != null ? ' · péremption ${DateFormat('dd/MM/yyyy').format(l.expiryDate!)}' : ''}'
                      '${l.discrepancyReason != null ? '\nÉcart : ${l.discrepancyReason}' : ''}',
                      style: AppTypography.caption,
                    ),
                  ),
                  Text('× ${l.qty}', style: AppTypography.bodyStrong),
                ],
              ),
            ),
          if (uploading) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: _progress),
          ] else
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (r.hasProof)
                  TextButton.icon(
                    key: ValueKey('view_proof_${r.id}'),
                    onPressed: () => _openProof(r),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Voir le justificatif'),
                  ),
                if (widget.canAddProof)
                  TextButton.icon(
                    key: ValueKey('add_proof_${r.id}'),
                    onPressed: () => _addProof(r),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: Text(
                      r.hasProof ? 'Ajouter une autre photo' : 'Ajouter la photo',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
