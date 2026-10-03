import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../di/di.dart';
import '../../../../shared/media/photo_source.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../stock/data/models/stock_option.dart';
import '../../../stock/data/repositories/stock_repository.dart';
import '../../data/models/goods_receipt_data.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/repositories/purchase_repository.dart';
import '../models/receipt_line_draft.dart';

/// Receiving a delivery against an order, partially or completely.
///
/// What the clinic needs to be able to trust afterwards: the lot number and
/// expiry date are the ones printed on the packaging (typed by the person
/// holding the box, never invented), the quantity cannot exceed what is still
/// expected, and the delivery note can be photographed as proof. The receipt
/// itself is recorded first; the photo is sent right after and, if that fails,
/// the receipt stays recorded and the missing proof is shown, not hidden.
class GoodsReceiptScreen extends StatefulWidget {
  final String poId;

  /// Replaced in tests so no camera is needed.
  final PhotoPicker? photoPicker;

  const GoodsReceiptScreen({super.key, required this.poId, this.photoPicker});

  @override
  State<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

enum _Phase { editing, sendingProof, proofFailed }

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  PurchaseOrderData? _po;
  final List<ReceiptLineDraft> _drafts = [];
  List<StockOption> _locations = [];
  String? _locationId;
  String? _loadError;
  bool _loading = true;
  bool _submitting = false;
  bool _showErrors = false;
  PickedPhoto? _photo;

  _Phase _phase = _Phase.editing;
  GoodsReceiptData? _recorded;
  double? _progress;
  String? _proofError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final po = await getIt<PurchaseRepository>().show(widget.poId);
      final options = await getIt<StockRepository>().listOptions(
        forceRefresh: true,
      );
      for (final d in _drafts) {
        d.dispose();
      }
      _drafts
        ..clear()
        ..addAll(po.lines.map(ReceiptLineDraft.new));
      if (!mounted) return;
      setState(() {
        _po = po;
        _locations = options.locations;
        _locationId = options.locations.isNotEmpty
            ? options.locations.first.id
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = ErrorMessage.from(e);
      });
    }
  }

  List<ReceiptLineDraft> get _included =>
      _drafts.where((d) => d.included).toList();

  bool get _formValid =>
      _locationId != null &&
      _included.isNotEmpty &&
      _drafts.every((d) => d.isValid());

  Future<void> _addPhoto() async {
    final picker = widget.photoPicker ?? PhotoSource.choose;
    final photo = await picker(context);
    if (photo == null || !mounted) return;
    setState(() => _photo = photo);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _showErrors = true);
    if (_locationId == null) {
      AppSnackbar.show(
        context,
        'Sélectionnez l\'emplacement de réception.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (_included.isEmpty) {
      AppSnackbar.show(
        context,
        'Aucune quantité à réceptionner.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (!_formValid) {
      AppSnackbar.show(
        context,
        'Corrigez les champs signalés avant de valider.',
        kind: SnackKind.warning,
      );
      return;
    }

    final units = _included.fold<int>(0, (s, d) => s + (d.qty ?? 0));
    final place = _locations.firstWhere((l) => l.id == _locationId).label;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Valider la réception ?',
      message:
          '$units unité(s) sur ${_included.length} ligne(s) seront ajoutées '
          'au stock : $place.\n\nLes lots et dates de péremption saisis ne '
          'pourront pas être modifiés depuis l\'application.',
      confirmLabel: 'Valider',
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    try {
      final receipt = await getIt<PurchaseRepository>().receive(
        poId: widget.poId,
        locationId: _locationId!,
        lines: _included.map((d) => d.toPayload()).toList(),
      );
      if (!mounted) return;

      if (receipt.isQueued) {
        AppSnackbar.show(
          context,
          _photo == null
              ? 'Enregistré localement. Synchronisation en attente.'
              : 'Enregistré localement. Ajoutez la photo depuis l\'historique '
                    'des réceptions une fois synchronisé.',
          kind: SnackKind.queued,
          actionLabel: 'Voir la file',
          onAction: () => context.push(Routes.sync),
        );
        context.popOrGo(Routes.purchases);
        return;
      }

      _recorded = receipt;
      if (_photo == null) {
        AppSnackbar.show(
          context,
          'Réception enregistrée. Pensez à ajouter la photo du bon de '
          'livraison.',
          kind: SnackKind.success,
        );
        context.popOrGo(Routes.purchases);
        return;
      }
      await _sendProof();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendProof() async {
    final photo = _photo;
    final receipt = _recorded;
    if (photo == null || receipt == null) return;
    setState(() {
      _phase = _Phase.sendingProof;
      _progress = 0;
      _proofError = null;
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
      AppSnackbar.show(
        context,
        'Réception et justificatif enregistrés.',
        kind: SnackKind.success,
      );
      context.popOrGo(Routes.purchases);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.proofFailed;
        _proofError = ErrorMessage.from(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Réception marchandise'),
      body: _loading
          ? const LoadingView()
          : _loadError != null
          ? ErrorView(message: _loadError!, onRetry: _load)
          : _po == null
          ? const ErrorView(message: 'Commande introuvable.')
          : _phase == _Phase.editing
          ? _buildForm()
          : _buildProofStatus(),
    );
  }

  Widget _buildProofStatus() {
    final failed = _phase == _Phase.proofFailed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
              size: 56,
              color: failed ? AppColors.warning : AppColors.brandPrimary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Réception enregistrée',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (failed) ...[
              Text(
                'Le stock est à jour, mais la photo du bon de livraison n\'a '
                'pas pu être envoyée : ${_proofError ?? 'erreur inconnue'}.',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Réessayer l\'envoi',
                icon: Icons.refresh,
                onPressed: _sendProof,
              ),
              TextButton(
                onPressed: () => context.popOrGo(Routes.purchases),
                child: const Text('Terminer sans justificatif'),
              ),
              const Text(
                'La réception sera signalée « justificatif manquant » dans '
                'l\'historique ; vous pourrez l\'ajouter plus tard.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ] else ...[
              const Text('Envoi de la photo…', style: AppTypography.body),
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: _progress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final po = _po!;
    var i = 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AnimatedListItem(
          index: i++,
          child: _locations.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Text(
                    'Aucun emplacement de stock. Demandez à un administrateur '
                    'd\'en créer un depuis l\'application web, puis revenez.',
                    style: AppTypography.caption,
                  ),
                )
              : AppDropdown<String>(
                  label: 'Emplacement de réception *',
                  value: _locationId,
                  options: _locations
                      .map((l) => AppDropdownOption(value: l.id, label: l.label))
                      .toList(),
                  onChanged: (v) => setState(() => _locationId = v),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedListItem(
          index: i++,
          child: const Text(
            'Lignes à réceptionner',
            style: AppTypography.sectionTitle,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Recopiez le numéro de lot et la date de péremption inscrits sur '
          'l\'emballage. Mettez 0 pour une ligne qui n\'est pas arrivée.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final d in _drafts) ...[
          AnimatedListItem(index: i++, child: _lineCard(d)),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        AnimatedListItem(index: i++, child: _photoCard()),
        const SizedBox(height: AppSpacing.xl),
        AnimatedListItem(
          index: i++,
          child: PrimaryButton(
            label: 'Valider la réception',
            isLoading: _submitting,
            onPressed: _submitting || po.lines.isEmpty ? null : _submit,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _lineCard(ReceiptLineDraft d) {
    final l = d.line;
    if (d.isComplete) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundSubtle,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${l.productName} : complet (${l.qtyReceived}/${l.qtyOrdered})',
                style: AppTypography.body,
              ),
            ),
          ],
        ),
      );
    }
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
          Text(l.productName, style: AppTypography.bodyStrong),
          const SizedBox(height: 4),
          Text(
            'Commandé : ${l.qtyOrdered} · déjà reçu : ${l.qtyReceived} · '
            'reste : ${l.qtyRemaining}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            key: ValueKey('qty_${l.id}'),
            label: 'Quantité reçue maintenant',
            controller: d.qtyCtrl,
            keyboardType: TextInputType.number,
            errorText: _showErrors || d.qtyCtrl.text.isNotEmpty
                ? d.qtyError
                : null,
            onChanged: (_) => setState(() {}),
          ),
          if (d.included) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: ValueKey('lot_${l.id}'),
              label: 'Numéro de lot (fabricant) *',
              controller: d.lotCtrl,
              errorText: _showErrors ? d.lotError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!d.noExpiry)
              AppDatePicker(
                key: ValueKey('exp_${l.id}'),
                label: 'Date de péremption *',
                value: d.expiry,
                firstDate: DateTime.now(),
                lastDate: DateTime(DateTime.now().year + 15),
                onChanged: (v) => setState(() => d.expiry = v),
              ),
            if (_showErrors && d.expiryError() != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  d.expiryError()!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            // The card paints its own background, so the tile needs its own
            // Material or its ink would be hidden under that decoration.
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: ValueKey('noexp_${l.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Ce produit n\'a pas de date de péremption',
                  style: AppTypography.caption,
                ),
                value: d.noExpiry,
                onChanged: (v) => setState(() {
                  d.noExpiry = v ?? false;
                  if (d.noExpiry) d.expiry = null;
                }),
              ),
            ),
            if (d.differsFromOrder) ...[
              const SizedBox(height: AppSpacing.xs),
              AppTextField(
                key: ValueKey('why_${l.id}'),
                label: 'Motif de l\'écart (conseillé)',
                hint: 'Ex : carton endommagé, livraison partielle',
                controller: d.reasonCtrl,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _photoCard() {
    final photo = _photo;
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
          const Text(
            'Photo du bon de livraison',
            style: AppTypography.bodyStrong,
          ),
          const SizedBox(height: 4),
          const Text(
            'Recommandée : c\'est la preuve de ce qui est arrivé. Sans photo, '
            'la réception reste signalée « justificatif manquant ».',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (photo == null)
            OutlinedButton.icon(
              key: const ValueKey('add_proof'),
              onPressed: _submitting ? null : _addPhoto,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Ajouter une photo'),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.memory(
                    photo.bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    photo.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
                IconButton(
                  key: const ValueKey('remove_proof'),
                  tooltip: 'Retirer la photo',
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _photo = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
