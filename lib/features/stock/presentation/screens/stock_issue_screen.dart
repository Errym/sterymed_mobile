import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_option.dart';
import '../../data/repositories/stock_repository.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/stock_options_loader.dart';

class StockIssueScreen extends StatelessWidget {
  const StockIssueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Sortie de stock'),
      body: StockOptionsLoader(
        builder: (ctx, batches, locations, reload) {
          if (batches.isEmpty || locations.isEmpty) {
            return _NoStockCard(
              missingBatch: batches.isEmpty,
              missingLocation: locations.isEmpty,
              onReload: reload,
            );
          }
          return _StockIssueForm(batches: batches, locations: locations);
        },
      ),
    );
  }
}

class _StockIssueForm extends StatefulWidget {
  final List<StockOption> batches;
  final List<StockOption> locations;

  const _StockIssueForm({required this.batches, required this.locations});

  @override
  State<_StockIssueForm> createState() => _StockIssueFormState();
}

class _StockIssueFormState extends State<_StockIssueForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String? _batchId;
  String? _locationId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _batchId = widget.batches.first.id;
    _locationId = widget.locations.first.id;
    _qtyCtrl.text = '1';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_batchId == null || _locationId == null) return;

    setState(() => _submitting = true);
    try {
      await getIt<StockRepository>().issue(
        batchId: _batchId!,
        locationId: _locationId!,
        qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        reason:
            _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Sortie enregistrée.', kind: SnackKind.success);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AnimatedListItem(
            index: 0,
            child: AppDropdown<String>(
              label: 'Lot *',
              value: _batchId,
              options: widget.batches
                  .map((b) => AppDropdownOption(value: b.id, label: b.label))
                  .toList(),
              onChanged: (v) => setState(() => _batchId = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 1,
            child: AppDropdown<String>(
              label: 'Emplacement *',
              value: _locationId,
              options: widget.locations
                  .map((l) => AppDropdownOption(value: l.id, label: l.label))
                  .toList(),
              onChanged: (v) => setState(() => _locationId = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 2,
            child: QuantityStepper(
              label: 'Quantité *',
              controller: _qtyCtrl,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis.';
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return 'Entrez un nombre positif.';
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedListItem(
            index: 3,
            child: AppTextArea(
              label: 'Motif (optionnel)',
              controller: _reasonCtrl,
              maxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedListItem(
            index: 4,
            child: PrimaryButton(
              label: 'Enregistrer la sortie',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoStockCard extends StatelessWidget {
  final bool missingBatch;
  final bool missingLocation;
  final Future<void> Function() onReload;

  const _NoStockCard({
    required this.missingBatch,
    required this.missingLocation,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final msg = missingBatch && missingLocation
        ? 'Aucun lot ni emplacement en stock.'
        : missingBatch
            ? 'Aucun lot en stock. Réceptionnez d\'abord une commande.'
            : 'Aucun emplacement configuré.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(msg,
                textAlign: TextAlign.center, style: AppTypography.bodyStrong),
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
