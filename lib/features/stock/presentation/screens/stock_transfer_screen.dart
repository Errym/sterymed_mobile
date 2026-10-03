import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/operator_name.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/pending_changes_banner.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/quantity_stepper.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/models/stock_option.dart';
import '../../data/repositories/stock_repository.dart';
import '../../domain/stock_rules.dart';
import '../widgets/stock_source_field.dart';
import '../widgets/stock_sources_loader.dart';

/// Moving stock from one place to another. The source is a lot that is really
/// at a place; the destination can only be another active place, never the
/// source itself.
class StockTransferScreen extends StatelessWidget {
  final String? batchId;
  final String? locationId;

  const StockTransferScreen({super.key, this.batchId, this.locationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Transfert de stock'),
      body: StockSourcesLoader(
        builder: (ctx, data, reload) {
          if (data.rows.isEmpty || data.locations.length < 2) {
            return _NoTransferCard(
              noStock: data.rows.isEmpty,
              onReload: reload,
            );
          }
          return StockTransferForm(
            data: data,
            reload: reload,
            batchId: batchId,
            locationId: locationId,
          );
        },
      ),
    );
  }
}

class StockTransferForm extends StatefulWidget {
  final StockSourcesData data;
  final Future<void> Function() reload;
  final String? batchId;
  final String? locationId;

  const StockTransferForm({
    super.key,
    required this.data,
    required this.reload,
    this.batchId,
    this.locationId,
  });

  @override
  State<StockTransferForm> createState() => _StockTransferFormState();
}

class _StockTransferFormState extends State<StockTransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  StockLevelData? _source;
  String? _toId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final batch = widget.batchId;
    if (batch != null) {
      final matches = widget.data.rows
          .where(
            (r) =>
                r.batchId == batch &&
                !r.isQuarantined &&
                (widget.locationId == null ||
                    r.locationId == widget.locationId),
          )
          .toList();
      if (matches.length == 1) _source = matches.first;
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _available => _source == null
      ? 0
      : StockRules.available(_source!, widget.data.pending);

  /// Every active place except the one the stock leaves.
  List<StockOption> get _destinations => widget.data.locations
      .where((l) => l.id != _source?.locationId)
      .toList();

  Future<void> _submit() async {
    final source = _source;
    if (source == null) {
      AppSnackbar.show(
        context,
        'Choisissez le lot et l\'emplacement d\'origine.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (_toId == null || _toId == source.locationId) {
      AppSnackbar.show(
        context,
        'Choisissez un emplacement de destination différent de l\'origine.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final result = await getIt<StockRepository>().transfer(
        batchId: source.batchId!,
        fromLocationId: source.locationId,
        toLocationId: _toId!,
        qty: int.parse(_qtyCtrl.text.trim()),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      final wasQueued = result.isQueued;
      AppSnackbar.show(
        context,
        wasQueued
            ? 'Enregistré localement. Synchronisation en attente.'
            : 'Transfert enregistré.',
        kind: wasQueued ? SnackKind.queued : SnackKind.success,
        actionLabel: wasQueued ? 'Voir la file' : null,
        onAction: wasQueued ? () => context.push(Routes.sync) : null,
      );
      context.popOrGo(Routes.stock);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
      await widget.reload();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Stock already at the destination for this lot, and what both places hold
  /// after the move.
  Widget _afterStrip(StockLevelData source) {
    int atDestination = 0;
    for (final r in widget.data.rows) {
      if (r.batchId == source.batchId && r.locationId == _toId) {
        atDestination = r.qty;
      }
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _qtyCtrl,
      builder: (context, value, _) {
        final qty = int.tryParse(value.text.trim());
        final moved = (qty == null || qty <= 0) ? 0 : qty;
        final bad = moved > _available;
        return StatStrip(
          icon: Icons.swap_horiz,
          label: 'Origine ${_available - (bad ? 0 : moved)} · '
              'Destination ${atDestination + (bad ? 0 : moved)}',
          tint: bad ? AppColors.dangerLight : null,
          value: Text(source.unit, style: AppTypography.caption),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final destinations = _destinations;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const PendingChangesBanner(resourceKey: 'stock:', matchPrefix: true),
          AnimatedListItem(
            index: 0,
            child: FormCard(
              title: 'Origine',
              trailing: const Text('Requis', style: AppTypography.caption),
              children: [
                StockSourceField(
                  label: 'Lot et emplacement d\'origine *',
                  rows: widget.data.rows,
                  selected: source,
                  pending: widget.data.pending,
                  onSelected: (r) => setState(() {
                    _source = r;
                    // The destination can never be where the stock comes from.
                    if (_toId == r.locationId) _toId = null;
                  }),
                ),
                if (source != null)
                  StatStrip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock au cabinet',
                    value: Text(
                      'Disponible : $_available ${source.unit}',
                      key: const ValueKey('available'),
                      style: AppTypography.bodyStrong,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 1,
            child: FormCard(
              title: 'Destination',
              trailing: const Text('Requis', style: AppTypography.caption),
              children: [
                AppDropdown<String>(
                  key: const ValueKey('destination'),
                  label: 'Emplacement de destination *',
                  value: destinations.any((l) => l.id == _toId) ? _toId : null,
                  hint:
                      source == null ? 'Choisissez d\'abord l\'origine' : null,
                  options: destinations
                      .map((l) => AppDropdownOption(value: l.id, label: l.label))
                      .toList(),
                  onChanged: (v) => setState(() => _toId = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 2,
            child: FormCard(
              title: 'Quantité à transférer',
              children: [
                QuantityStepper(
                  label: 'Quantité *',
                  controller: _qtyCtrl,
                  max: source == null ? 999999 : _available.clamp(1, 999999),
                  validator: (v) => StockRules.takeQtyError(v, _available),
                ),
                if (source != null)
                  QuickAmountChips(
                    controller: _qtyCtrl,
                    max: _available,
                  ),
                if (source != null && _toId != null) _afterStrip(source),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 3,
            child: FormCard(
              title: 'Justification',
              trailing: const Text('Facultatif', style: AppTypography.caption),
              children: [
                AppTextArea(
                  label: 'Motif (optionnel)',
                  controller: _reasonCtrl,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          NoteStrip(
            text: 'Transfert enregistré sous le nom de '
                '${operatorName()}.',
          ),
        ],
      ),
    ),
          PinnedFooter(
            child: FormFooter(
                primary: PrimaryButton(
                  label: 'Enregistrer le transfert',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                onCancel: _submitting ? null : () => context.popOrGo(Routes.stock),
              ),
          ),
        ],
      ),
    );
  }
}

class _NoTransferCard extends StatelessWidget {
  final bool noStock;
  final Future<void> Function() onReload;

  const _NoTransferCard({required this.noStock, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final msg = noStock
        ? 'Aucun lot en stock à transférer.'
        : 'Il faut au moins deux emplacements actifs pour transférer du stock.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_horiz,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(msg, textAlign: TextAlign.center, style: AppTypography.bodyStrong),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => onReload(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
