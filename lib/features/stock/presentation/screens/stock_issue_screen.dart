import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/operator_name.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/pending_changes_banner.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/quantity_stepper.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';
import '../../domain/stock_rules.dart';
import '../widgets/stock_source_field.dart';
import '../widgets/stock_sources_loader.dart';

/// Taking stock out of a place. The source is one row of "this lot at this
/// place" that really has stock, so the quantity can be bounded by what is
/// there. [batchId] / [locationId] preselect it when the user comes from a
/// scan or a stock list.
class StockIssueScreen extends StatelessWidget {
  final String? batchId;
  final String? locationId;

  const StockIssueScreen({super.key, this.batchId, this.locationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Sortie de stock'),
      body: StockSourcesLoader(
        builder: (ctx, data, reload) {
          if (data.rows.isEmpty) {
            return _NoStockCard(onReload: reload);
          }
          return StockIssueForm(
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

class StockIssueForm extends StatefulWidget {
  final StockSourcesData data;
  final Future<void> Function() reload;
  final String? batchId;
  final String? locationId;

  const StockIssueForm({
    super.key,
    required this.data,
    required this.reload,
    this.batchId,
    this.locationId,
  });

  @override
  State<StockIssueForm> createState() => _StockIssueFormState();
}

class _StockIssueFormState extends State<StockIssueForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  StockLevelData? _source;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _source = _preselected();
  }

  /// The row the caller pointed at, if it is unambiguous and usable.
  StockLevelData? _preselected() {
    final batch = widget.batchId;
    if (batch == null) return null;
    final matches = widget.data.rows
        .where(
          (r) =>
              r.batchId == batch &&
              !r.isQuarantined &&
              (widget.locationId == null || r.locationId == widget.locationId),
        )
        .toList();
    return matches.length == 1 ? matches.first : null;
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

  bool get _reasonRequired =>
      _source != null && StockRules.issueNeedsReason(_source!);

  Future<void> _submit() async {
    final source = _source;
    if (source == null) {
      AppSnackbar.show(
        context,
        'Choisissez le lot et l\'emplacement.',
        kind: SnackKind.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final result = await getIt<StockRepository>().issue(
        batchId: source.batchId!,
        locationId: source.locationId,
        qty: int.parse(_qtyCtrl.text.trim()),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      final wasQueued = result.isQueued;
      AppSnackbar.show(
        context,
        wasQueued
            ? 'Enregistré localement. Synchronisation en attente.'
            : 'Sortie enregistrée.',
        kind: wasQueued ? SnackKind.queued : SnackKind.success,
        actionLabel: wasQueued ? 'Voir la file' : null,
        onAction: wasQueued ? () => context.push(Routes.sync) : null,
      );
      context.popOrGo(Routes.stock);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
      // The balance on screen may be out of date (another operator, another
      // device): show the real one before the user tries again.
      await widget.reload();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
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
              title: 'Lot à sortir',
              trailing: const Text('Requis', style: AppTypography.caption),
              children: [
                StockSourceField(
                  rows: widget.data.rows,
                  selected: source,
                  pending: widget.data.pending,
                  onSelected: (r) => setState(() => _source = r),
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
              title: 'Quantité à sortir',
              children: [
                QuantityStepper(
                  label: 'Quantité *',
                  controller: _qtyCtrl,
                  max: source == null ? 999999 : _available.clamp(1, 999999),
                  validator: (v) => StockRules.takeQtyError(v, _available),
                ),
                if (source != null) _remainingStrip(source.unit),
              ],
            ),
          ),
          if (_reasonRequired) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const ValueKey('expired_banner'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: const Text(
                'Ce lot est périmé. Il doit quitter le stock : indiquez le '
                'motif (par exemple « mise au rebut »).',
                style: AppTypography.caption,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 2,
            child: FormCard(
              title: 'Justification',
              trailing: Text(
                _reasonRequired ? 'Requis' : 'Facultatif',
                style: AppTypography.caption,
              ),
              children: [
                AppTextArea(
                  label: _reasonRequired ? 'Motif *' : 'Motif (optionnel)',
                  controller: _reasonCtrl,
                  maxLines: 2,
                  validator: (v) =>
                      _reasonRequired && (v == null || v.trim().isEmpty)
                      ? 'Le motif est obligatoire pour un lot périmé.'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          NoteStrip(
            text: 'La sortie est enregistrée au registre de traçabilité '
                'sous le nom de ${operatorName()}.',
          ),
        ],
      ),
    ),
          PinnedFooter(
            child: FormFooter(
                primary: PrimaryButton(
                  label: 'Enregistrer la sortie',
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

  /// "Nouveau stock restant", live as the quantity changes.
  Widget _remainingStrip(String unit) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _qtyCtrl,
      builder: (context, value, _) {
        final qty = int.tryParse(value.text.trim());
        final left = (qty == null || qty <= 0) ? _available : _available - qty;
        final over = left < 0;
        return StatStrip(
          icon: Icons.published_with_changes_outlined,
          label: 'Nouveau stock restant',
          tint: over ? AppColors.dangerLight : null,
          value: Text(
            '${over ? 0 : left} $unit',
            style: AppTypography.bodyStrong.copyWith(
              color: over ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        );
      },
    );
  }
}

class _NoStockCard extends StatelessWidget {
  final Future<void> Function() onReload;
  const _NoStockCard({required this.onReload});

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
              'Aucun lot en stock. Réceptionnez d\'abord une commande.',
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
