import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/stock_option.dart';
import '../../data/repositories/stock_repository.dart';
import '../widgets/stock_options_loader.dart';

class StockTransferScreen extends StatelessWidget {
  const StockTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Transfert de stock'),
      body: StockOptionsLoader(
        builder: (ctx, batches, locations, reload) {
          if (batches.isEmpty || locations.length < 2) {
            return _NoTransferCard(
              batchesEmpty: batches.isEmpty,
              locationsInsufficient: locations.length < 2,
              onReload: reload,
            );
          }
          return _StockTransferForm(batches: batches, locations: locations);
        },
      ),
    );
  }
}

class _StockTransferForm extends StatefulWidget {
  final List<StockOption> batches;
  final List<StockOption> locations;

  const _StockTransferForm({required this.batches, required this.locations});

  @override
  State<_StockTransferForm> createState() => _StockTransferFormState();
}

class _StockTransferFormState extends State<_StockTransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String? _batchId;
  String? _fromId;
  String? _toId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _batchId = widget.batches.first.id;
    _fromId = widget.locations.first.id;
    _toId = widget.locations.length > 1 ? widget.locations[1].id : null;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromId == _toId) {
      AppSnackbar.show(context, 'Choisissez deux emplacements différents.',
          kind: SnackKind.warning);
      return;
    }
    if (_batchId == null || _fromId == null || _toId == null) return;

    setState(() => _submitting = true);
    try {
      await getIt<StockRepository>().transfer(
        batchId: _batchId!,
        fromLocationId: _fromId!,
        toLocationId: _toId!,
        qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Transfert enregistré.',
          kind: SnackKind.success);
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
          AppDropdown<String>(
            label: 'Lot *',
            value: _batchId,
            options: widget.batches
                .map((b) => AppDropdownOption(value: b.id, label: b.label))
                .toList(),
            onChanged: (v) => setState(() => _batchId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String>(
            label: 'Depuis *',
            value: _fromId,
            options: widget.locations
                .map((l) => AppDropdownOption(value: l.id, label: l.label))
                .toList(),
            onChanged: (v) => setState(() => _fromId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String>(
            label: 'Vers *',
            value: _toId,
            options: widget.locations
                .map((l) => AppDropdownOption(value: l.id, label: l.label))
                .toList(),
            onChanged: (v) => setState(() => _toId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Quantité *',
            hint: 'ex. 3',
            keyboardType: TextInputType.number,
            controller: _qtyCtrl,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requis.';
              final n = int.tryParse(v.trim());
              if (n == null || n <= 0) return 'Entrez un nombre positif.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextArea(
            label: 'Motif (optionnel)',
            controller: _reasonCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Enregistrer le transfert',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _NoTransferCard extends StatelessWidget {
  final bool batchesEmpty;
  final bool locationsInsufficient;
  final Future<void> Function() onReload;

  const _NoTransferCard({
    required this.batchesEmpty,
    required this.locationsInsufficient,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final msg = batchesEmpty
        ? 'Aucun lot en stock. Réceptionnez une commande d\'abord.'
        : locationsInsufficient
            ? 'Un transfert nécessite au moins deux emplacements.'
            : 'Données manquantes.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(msg,
                textAlign: TextAlign.center,
                style: AppTypography.bodyStrong),
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
