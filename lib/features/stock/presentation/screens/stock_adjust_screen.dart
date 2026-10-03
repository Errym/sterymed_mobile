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
import '../../data/repositories/stock_repository.dart';
import '../../domain/stock_rules.dart';
import '../widgets/stock_source_field.dart';
import '../widgets/stock_sources_loader.dart';

/// A correction with a mandatory reason: remove what is missing or damaged
/// (bounded by what is there), or add stock that was found (to any active
/// place). An inventory count produces its own corrections; this is for the
/// one-off case.
class StockAdjustScreen extends StatelessWidget {
  final String? batchId;
  final String? locationId;

  const StockAdjustScreen({super.key, this.batchId, this.locationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Ajustement de stock'),
      body: StockSourcesLoader(
        builder: (ctx, data, reload) {
          if (data.locations.isEmpty) {
            return _NoPlaceCard(onReload: reload);
          }
          return StockAdjustForm(
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

enum _Direction { remove, add }

class StockAdjustForm extends StatefulWidget {
  final StockSourcesData data;
  final Future<void> Function() reload;
  final String? batchId;
  final String? locationId;

  const StockAdjustForm({
    super.key,
    required this.data,
    required this.reload,
    this.batchId,
    this.locationId,
  });

  @override
  State<StockAdjustForm> createState() => _StockAdjustFormState();
}

class _StockAdjustFormState extends State<StockAdjustForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  _Direction _direction = _Direction.remove;
  StockLevelData? _source; // remove: the row to take from
  String? _batchId; // add: the lot found
  String? _locationId; // add: where it was found
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
                (widget.locationId == null ||
                    r.locationId == widget.locationId),
          )
          .toList();
      if (matches.length == 1) _source = matches.first;
      _batchId = batch;
      _locationId = widget.locationId;
    }
    if (widget.data.rows.isEmpty) _direction = _Direction.add;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _removing => _direction == _Direction.remove;

  int get _available => _source == null
      ? 0
      : StockRules.available(_source!, widget.data.pending);

  Future<void> _submit() async {
    final String batchId;
    final String locationId;
    if (_removing) {
      final source = _source;
      if (source == null) {
        AppSnackbar.show(
          context,
          'Choisissez le lot et l\'emplacement concernés.',
          kind: SnackKind.warning,
        );
        return;
      }
      batchId = source.batchId!;
      locationId = source.locationId;
    } else {
      if (_batchId == null || _locationId == null) {
        AppSnackbar.show(
          context,
          'Choisissez le lot trouvé et son emplacement.',
          kind: SnackKind.warning,
        );
        return;
      }
      batchId = _batchId!;
      locationId = _locationId!;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    final magnitude = int.parse(_qtyCtrl.text.trim());
    setState(() => _submitting = true);
    try {
      final result = await getIt<StockRepository>().adjust(
        batchId: batchId,
        locationId: locationId,
        qty: _removing ? -magnitude : magnitude,
        reason: _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      final wasQueued = result.isQueued;
      AppSnackbar.show(
        context,
        wasQueued
            ? 'Enregistré localement. Synchronisation en attente.'
            : 'Ajustement enregistré.',
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

  /// "Nouveau stock : 12 boîtes", live as the quantity changes. Only when the
  /// current balance is known (a removal from a chosen lot, or an addition to a
  /// lot and place that already hold stock).
  Widget _resultStrip() {
    StockLevelData? row;
    if (_removing) {
      row = _source;
    } else {
      for (final r in widget.data.rows) {
        if (r.batchId == _batchId && r.locationId == _locationId) row = r;
      }
    }
    if (row == null) return const SizedBox.shrink();
    final unit = row.unit;
    final base = _removing ? _available : row.qty;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _qtyCtrl,
      builder: (context, value, _) {
        final qty = int.tryParse(value.text.trim());
        final next = (qty == null || qty <= 0)
            ? base
            : (_removing ? base - qty : base + qty);
        final bad = next < 0;
        return StatStrip(
          icon: Icons.published_with_changes_outlined,
          label: 'Nouveau stock',
          tint: bad ? AppColors.dangerLight : null,
          value: Text(
            '${bad ? 0 : next} $unit',
            style: AppTypography.bodyStrong.copyWith(
              color: bad ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final noStockToRemove = widget.data.rows.isEmpty;
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
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Un ajustement corrige un écart (casse, perte, lot '
                      'retrouvé). Le motif est obligatoire.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 1,
            child: SegmentedButton<_Direction>(
              key: const ValueKey('direction'),
              segments: [
                ButtonSegment(
                  value: _Direction.remove,
                  label: const Text('Retirer'),
                  icon: const Icon(Icons.remove_circle_outline),
                  enabled: !noStockToRemove,
                ),
                const ButtonSegment(
                  value: _Direction.add,
                  label: Text('Ajouter'),
                  icon: Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 2,
            child: FormCard(
              title: _removing ? 'Lot à corriger' : 'Lot retrouvé',
              trailing: const Text('Requis', style: AppTypography.caption),
              children: [
                if (_removing) ...[
                  StockSourceField(
                    rows: widget.data.rows,
                    selected: _source,
                    pending: widget.data.pending,
                    allowQuarantined: true,
                    onSelected: (r) => setState(() => _source = r),
                  ),
                  if (_source != null)
                    StatStrip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock au cabinet',
                      value: Text(
                        'Disponible : $_available ${_source!.unit}',
                        key: const ValueKey('available'),
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                ] else ...[
                  AppDropdown<String>(
                    key: const ValueKey('add_batch'),
                    label: 'Lot retrouvé *',
                    value: widget.data.batches.any((b) => b.id == _batchId)
                        ? _batchId
                        : null,
                    options: widget.data.batches
                        .map((b) =>
                            AppDropdownOption(value: b.id, label: b.label))
                        .toList(),
                    onChanged: (v) => setState(() => _batchId = v),
                  ),
                  AppDropdown<String>(
                    key: const ValueKey('add_location'),
                    label: 'Emplacement *',
                    value: widget.data.locations.any((l) => l.id == _locationId)
                        ? _locationId
                        : null,
                    options: widget.data.locations
                        .map((l) =>
                            AppDropdownOption(value: l.id, label: l.label))
                        .toList(),
                    onChanged: (v) => setState(() => _locationId = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 3,
            child: FormCard(
              title: _removing ? 'Quantité à retirer' : 'Quantité à ajouter',
              children: [
                QuantityStepper(
                  label:
                      _removing ? 'Quantité à retirer *' : 'Quantité à ajouter *',
                  controller: _qtyCtrl,
                  max: _removing && _source != null
                      ? _available.clamp(1, 999999)
                      : 999999,
                  validator: (v) => StockRules.adjustQtyError(
                    v,
                    available: _removing && _source != null ? _available : null,
                  ),
                ),
                _resultStrip(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 4,
            child: FormCard(
              title: 'Justification',
              trailing: const Text('Requis', style: AppTypography.caption),
              children: [
                ReasonPresetChips(
                  controller: _reasonCtrl,
                  presets: const [
                    'Livraison non enregistrée',
                    'Erreur de comptage',
                    'Produit périmé mis au rebut',
                    'Casse ou avarie',
                  ],
                ),
                AppTextArea(
                  label: 'Motif (obligatoire) *',
                  controller: _reasonCtrl,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Le motif est obligatoire pour un ajustement.'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          NoteStrip(
            text: 'Cet ajustement est horodaté et archivé sous la responsabilité de '
                '${operatorName()}.',
          ),
        ],
      ),
    ),
          PinnedFooter(
            child: FormFooter(
                primary: PrimaryButton(
                  label: 'Enregistrer l\'ajustement',
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

class _NoPlaceCard extends StatelessWidget {
  final Future<void> Function() onReload;
  const _NoPlaceCard({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Aucun emplacement actif configuré.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong,
            ),
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
