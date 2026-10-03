import 'package:flutter/material.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/pending_changes_banner.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/feedback/reason_dialog.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../suppliers/data/models/supplier_data.dart';
import '../../../suppliers/data/repositories/supplier_repository.dart';
import '../../data/models/purchase_order_data.dart';
import '../../data/models/purchase_order_line_data.dart';
import '../../data/repositories/purchase_repository.dart';
import '../widgets/purchase_order_create_sheet.dart';
import '../widgets/purchase_order_stepper.dart';
import '../widgets/receipt_history_section.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String poId;
  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  late Future<PurchaseOrderData> _future;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _future = getIt<PurchaseRepository>().show(widget.poId);
  }

  Future<void> _reload() async {
    setState(() => _future = getIt<PurchaseRepository>().show(widget.poId));
    await _future;
  }

  Future<void> _markOrdered() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Marquer comme commandée ?',
      message: 'La commande sera envoyée au fournisseur.',
      confirmLabel: 'Confirmer',
    );
    if (!ok || !mounted) return;
    setState(() => _marking = true);
    try {
      await getIt<PurchaseRepository>().markOrdered(widget.poId);
      if (!mounted) return;
      AppSnackbar.show(context, 'Commande marquée comme envoyée.',
          kind: SnackKind.success);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _edit(PurchaseOrderData po) async {
    final changed = await PurchaseOrderCreateSheet.show(context, editing: po);
    if (changed == true && mounted) await _reload();
  }

  Future<void> _cancel(PurchaseOrderData po) async {
    final reason = await ReasonDialog.show(
      context,
      title: 'Annuler cette commande ?',
      message: po.status == 'draft'
          ? 'Le brouillon sera annulé.'
          : 'La commande est déjà passée au fournisseur : prévenez-le. '
                'Ce qui a déjà été réceptionné reste en stock.',
      confirmLabel: 'Annuler la commande',
      hint: 'Motif (optionnel)',
      required: false,
    );
    if (reason == null || !mounted) return;
    setState(() => _marking = true);
    try {
      await getIt<PurchaseRepository>().cancel(
        widget.poId,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Commande annulée.', kind: SnackKind.success);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _receive(PurchaseOrderData po) async {
    await context.push(Routes.goodsReceipt(po.id));
    if (mounted) await _reload();
  }

  // Backend enum (PurchaseOrderStatus): draft, ordered, partially_received,
  // received, closed, cancelled.
  String _statusLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Brouillon';
      case 'ordered':
        return 'Commandé';
      case 'partially_received':
        return 'Partiel';
      case 'received':
        return 'Reçu';
      case 'closed':
        return 'Clôturé';
      case 'cancelled':
        return 'Annulé';
      default:
        return s;
    }
  }

  BadgeTone _statusTone(String s) {
    switch (s) {
      case 'ordered':
        return BadgeTone.blue;
      case 'partially_received':
        return BadgeTone.orange;
      case 'received':
        return BadgeTone.green;
      case 'closed':
        return BadgeTone.gray;
      case 'cancelled':
        return BadgeTone.gray;
      default:
        return BadgeTone.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Commande'),
      body: FutureBuilder<PurchaseOrderData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError || !snap.hasData) {
            return ErrorView(
              message: 'Impossible de charger la commande.',
              onRetry: _reload,
            );
          }
          final po = snap.data!;
          final canManage =
              getIt<SessionStore>().hasPermission('purchasing.manage');
          var i = 0;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              PendingChangesBanner(resourceKey: 'purchase:${widget.poId}'),
              AnimatedListItem(
                index: i++,
                child: _OrderHeader(
                  po: po,
                  statusLabel: _statusLabel(po.status),
                  statusTone: _statusTone(po.status),
                ),
              ),
              if (po.status != 'cancelled') ...[
                const SizedBox(height: AppSpacing.lg),
                AnimatedListItem(
                  index: i++,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: AppShadows.card,
                    ),
                    child: PurchaseOrderStepper(status: po.status),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AnimatedListItem(
                index: i++,
                child: SectionHeader(title: 'Lignes (${po.lines.length})'),
              ),
              for (final l in po.lines)
                AnimatedListItem(index: i++, child: _LineTile(line: l)),
              if (po.status != 'draft') ...[
                const SizedBox(height: AppSpacing.lg),
                AnimatedListItem(
                  index: i++,
                  child: const SectionHeader(title: 'Réceptions'),
                ),
                AnimatedListItem(
                  index: i++,
                  child: ReceiptHistorySection(
                    key: ValueKey('receipts_${po.status}_${po.qtyRemaining}'),
                    poId: po.id,
                    canAddProof: canManage,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (po.canOrder && canManage)
                AnimatedListItem(
                  index: i++,
                  child: PrimaryButton(
                    label: 'Marquer comme commandée',
                    icon: Icons.send,
                    isLoading: _marking,
                    onPressed: _marking ? null : _markOrdered,
                  ),
                ),
              if (po.canEdit && canManage)
                AnimatedListItem(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: OutlinedButton.icon(
                      key: const ValueKey('edit_order'),
                      onPressed: _marking ? null : () => _edit(po),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier la commande'),
                    ),
                  ),
                ),
              if (po.canReceive && canManage)
                AnimatedListItem(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: PrimaryButton(
                      label: 'Réceptionner',
                      icon: Icons.inbox_outlined,
                      onPressed: () => _receive(po),
                    ),
                  ),
                ),
              if (po.canCancel && canManage)
                AnimatedListItem(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextButton.icon(
                      key: const ValueKey('cancel_order'),
                      onPressed: _marking ? null : () => _cancel(po),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      label: const Text(
                        'Annuler la commande',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final PurchaseOrderLineData line;
  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final complete = line.qtyReceived >= line.qtyOrdered;
    final price = line.unitPrice;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EntityMark.icon(Icons.inventory_2_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.productName, style: AppTypography.bodyStrong),
                      Text(
                        '${line.qtyOrdered} commandé(s)'
                        '${price == null ? '' : ' × ${AppCurrencyFormatter.eur(price)}'}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Text(
                    AppCurrencyFormatter.eur(price * line.qtyOrdered),
                    style: AppTypography.metric.copyWith(
                      fontSize: 16,
                      color: AppColors.brandPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: line.qtyOrdered == 0
                          ? 0
                          : line.qtyReceived / line.qtyOrdered,
                      minHeight: 6,
                      backgroundColor: AppColors.backgroundMuted,
                      color:
                          complete ? AppColors.success : AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${line.qtyReceived}/${line.qtyOrdered}',
                  style: AppTypography.bodyStrong.copyWith(
                    color: complete ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (!complete && line.qtyReceived > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Reste ${line.qtyRemaining} à recevoir',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The top of an order: who it is for (with the ways to reach them), what it
/// is worth, how much is still to come, and whether delivery is late.
class _OrderHeader extends StatefulWidget {
  final PurchaseOrderData po;
  final String statusLabel;
  final BadgeTone statusTone;
  const _OrderHeader({
    required this.po,
    required this.statusLabel,
    required this.statusTone,
  });

  @override
  State<_OrderHeader> createState() => _OrderHeaderState();
}

class _OrderHeaderState extends State<_OrderHeader> {
  SupplierData? _supplier;

  @override
  void initState() {
    super.initState();
    _loadSupplier();
  }

  /// The supplier's phone, e-mail and address, when the role may read them.
  /// A failure only means no contact buttons: the order itself is unaffected.
  Future<void> _loadSupplier() async {
    final session = getIt<SessionStore>();
    if (!session.hasPermission('suppliers.view') ||
        widget.po.supplierId.isEmpty) {
      return;
    }
    try {
      final s = await getIt<SupplierRepository>().show(widget.po.supplierId);
      if (mounted) setState(() => _supplier = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final po = widget.po;
    final today = DateTime.now();
    final expected = po.expectedAt;
    final open = po.status == 'ordered' || po.status == 'partially_received';
    final lateDays = (expected != null && open)
        ? DateTime(today.year, today.month, today.day)
            .difference(DateTime(expected.year, expected.month, expected.day))
            .inDays
        : 0;
    final ordered = po.lines.fold<int>(0, (s, l) => s + l.qtyOrdered);
    final received = po.lines.fold<int>(0, (s, l) => s + l.qtyReceived);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityMark.initials(EntityMark.initialsOf(po.supplierName)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${po.shortId}  ·  '
                      '${DateFormat('dd/MM/yyyy').format(po.createdAt)}',
                      style: AppTypography.eyebrow,
                    ),
                    const SizedBox(height: 2),
                    Text(po.supplierName, style: AppTypography.sectionTitle),
                  ],
                ),
              ),
              TypeBadge(label: widget.statusLabel, tone: widget.statusTone),
            ],
          ),
          if (_supplier != null) ...[
            const SizedBox(height: AppSpacing.md),
            ContactActions(
              phone: _supplier!.phone,
              email: _supplier!.email,
              address: _supplier!.address,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeaderFigure(
                  label: 'TOTAL ESTIMÉ',
                  value: po.totalAmount == null
                      ? '—'
                      : AppCurrencyFormatter.eur(po.totalAmount!),
                  color: AppColors.brandPrimary,
                ),
              ),
              Expanded(
                child: _HeaderFigure(
                  label: 'REÇU',
                  value: ordered == 0 ? '—' : '$received / $ordered',
                ),
              ),
              Expanded(
                child: _HeaderFigure(
                  label: 'LIGNES',
                  value: '${po.lines.length}',
                ),
              ),
            ],
          ),
          if (expected != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: lateDays > 0
                    ? AppColors.dangerLight
                    : AppColors.surfaceWell,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: [
                  Icon(
                    lateDays > 0
                        ? Icons.warning_amber_outlined
                        : Icons.local_shipping_outlined,
                    size: 18,
                    color: lateDays > 0
                        ? AppColors.danger
                        : AppColors.navyHeader,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Livraison prévue le '
                      '${DateFormat('dd/MM/yyyy').format(expected)}',
                      style: AppTypography.body,
                    ),
                  ),
                  if (lateDays > 0)
                    Text(
                      'En retard de $lateDays j',
                      style: AppTypography.bodyStrong
                          .copyWith(color: AppColors.danger),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderFigure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _HeaderFigure({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.eyebrow.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTypography.metric.copyWith(fontSize: 18, color: color),
          ),
        ),
      ],
    );
  }
}
