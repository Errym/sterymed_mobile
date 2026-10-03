import 'package:flutter/material.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/feedback/reason_dialog.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/inventory_count_data.dart';
import '../../data/repositories/inventory_count_repository.dart';
import 'inventory_count_list_screen.dart';

/// One inventory session: count each lot of the place, see the difference with
/// the system, then close (which writes the adjustments) or cancel.
class InventoryCountDetailScreen extends StatefulWidget {
  final String countId;
  const InventoryCountDetailScreen({super.key, required this.countId});

  @override
  State<InventoryCountDetailScreen> createState() =>
      _InventoryCountDetailScreenState();
}

class _InventoryCountDetailScreenState
    extends State<InventoryCountDetailScreen> {
  InventoryCountDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _detail == null;
      _error = null;
    });
    try {
      final d = await getIt<InventoryCountRepository>().show(widget.countId);
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  /// Runs a server action, shows a failure instead of swallowing it, and
  /// re-reads the session so the screen always shows the server's truth.
  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _count({
    required String batchId,
    required String title,
    int? initial,
  }) async {
    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _CountDialog(title: title, initial: initial),
    );
    if (qty == null) return;
    await _run(
      () => getIt<InventoryCountRepository>().recordLine(
        countId: widget.countId,
        batchId: batchId,
        countedQty: qty,
      ),
    );
  }

  Future<void> _close(InventoryCountDetail d) async {
    final left = d.uncounted.length;
    final changes = d.lines.where((l) => l.variance != 0).length;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Terminer l\'inventaire ?',
      message: left > 0
          ? '$left lot(s) n\'ont pas été comptés et resteront inchangés. '
                '$changes ajustement(s) seront enregistrés dans le stock.'
          : '$changes ajustement(s) seront enregistrés dans le stock. '
                'Cette action est définitive.',
      confirmLabel: 'Terminer',
    );
    if (!ok) return;
    final done = await _run(
      () => getIt<InventoryCountRepository>().close(
        widget.countId,
        acknowledgeUncounted: left > 0,
      ),
    );
    if (done && mounted) {
      AppSnackbar.show(context, 'Inventaire terminé.', kind: SnackKind.success);
    }
  }

  Future<void> _cancel() async {
    final reason = await ReasonDialog.show(
      context,
      title: 'Annuler l\'inventaire ?',
      message:
          'Aucun ajustement ne sera enregistré. Indiquez pourquoi il est '
          'annulé.',
      confirmLabel: 'Annuler l\'inventaire',
    );
    if (reason == null) return;
    await _run(
      () => getIt<InventoryCountRepository>().cancel(
        widget.countId,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: d?.summary.locationName ?? 'Inventaire',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const LoadingView(message: 'Chargement...')
          : d == null
          ? ErrorView(message: _error ?? 'Erreur', onRetry: _load)
          : _content(d),
    );
  }

  Widget _content(InventoryCountDetail d) {
    final s = d.summary;
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    final editable = s.isOpen && canManage;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.locationName,
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                    StatusBadge(
                      label: inventoryStatusLabel(s),
                      tone: inventoryStatusTone(s),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ouvert par ${s.openedByName}'
                  '${s.openedAt == null ? '' : ' le ${AppDateFormatter.dateTime(s.openedAt!.toLocal())}'}',
                  style: AppTypography.caption,
                ),
                if (s.note != null && s.note!.isNotEmpty)
                  Text('Note : ${s.note}', style: AppTypography.caption),
                if (s.isClosed)
                  Text(
                    'Terminé par ${s.closedByName ?? '—'}'
                    '${s.closedAt == null ? '' : ' le ${AppDateFormatter.dateTime(s.closedAt!.toLocal())}'}'
                    ' · ${s.adjustmentsCount} ajustement(s)',
                    style: AppTypography.caption,
                  ),
                if (s.isCancelled)
                  Text(
                    'Annulé : ${s.cancelReason ?? '—'}',
                    style: AppTypography.caption,
                  ),
                const SizedBox(height: AppSpacing.md),
                _CountProgress(detail: d),
              ],
            ),
          ),
          if (s.isOpen && !canManage) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Lecture seule : votre rôle ne permet pas de compter.',
              style: AppTypography.caption,
            ),
          ],
          if (s.isOpen) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: 'À compter (${d.uncounted.length})'),
            if (d.uncounted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Tous les lots de cet emplacement ont été comptés.',
                  style: AppTypography.caption,
                ),
              ),
            for (final u in d.uncounted)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.productName,
                              style: AppTypography.bodyStrong,
                            ),
                            Text(
                              'Lot ${u.batchNumber}'
                              '${u.expiryDate == null ? '' : ' · exp. ${AppDateFormatter.date(u.expiryDate!)}'}'
                              ' · système : ${u.systemQty}',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      if (editable)
                        FilledButton(
                          key: ValueKey('count_${u.batchId}'),
                          onPressed: _busy
                              ? null
                              : () => _count(
                                  batchId: u.batchId,
                                  title: '${u.productName} · ${u.batchNumber}',
                                ),
                          child: const Text('Compter'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Comptés (${d.lines.length})'),
          if (d.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Aucun lot compté.', style: AppTypography.caption),
            ),
          for (final l in d.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: editable && !_busy
                    ? () => _count(
                        batchId: l.batchId,
                        title: '${l.productName} · ${l.batchNumber}',
                        initial: l.countedQty,
                      )
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.productName, style: AppTypography.bodyStrong),
                          Text(
                            'Lot ${l.batchNumber} · système ${l.expectedQty}'
                            ' · compté ${l.countedQty}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: l.variance == 0
                          ? 'Conforme'
                          : l.variance > 0
                          ? '+${l.variance}'
                          : '${l.variance}',
                      tone: l.variance == 0
                          ? StatusTone.success
                          : StatusTone.warning,
                    ),
                  ],
                ),
              ),
            ),
          if (editable) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Terminer l\'inventaire',
              isLoading: _busy,
              onPressed: _busy || d.lines.isEmpty ? null : () => _close(d),
            ),
            if (d.lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Comptez au moins un lot pour pouvoir terminer.',
                  style: AppTypography.caption,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Annuler l\'inventaire',
              onPressed: _busy ? null : _cancel,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Asks for the quantity actually found on the shelf. Zero is a real answer.
class _CountDialog extends StatefulWidget {
  final String title;
  final int? initial;
  const _CountDialog({required this.title, this.initial});

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_ctrl.text.trim());
    if (n == null || n < 0 || n > 1000000) {
      setState(
        () => _error = 'Entrez un nombre entier (0 si l\'étagère est vide).',
      );
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('count_qty'),
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Quantité comptée',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}


/// How far the count is: counted lots over all lots of the place, and how many
/// of the counted ones differ from the system.
class _CountProgress extends StatelessWidget {
  final InventoryCountDetail detail;
  const _CountProgress({required this.detail});

  @override
  Widget build(BuildContext context) {
    final counted = detail.lines.length;
    final left = detail.summary.isOpen ? detail.uncounted.length : 0;
    final total = counted + left;
    final gaps = detail.lines.where((l) => l.variance != 0).length;
    final value = total == 0 ? 0.0 : counted / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: AppColors.backgroundMuted,
            valueColor: AlwaysStoppedAnimation<Color>(
              left == 0 ? AppColors.success : AppColors.brandPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _Stat('COMPTÉS', '$counted${total > 0 ? ' / $total' : ''}'),
            _Stat('À COMPTER', '$left'),
            _Stat(
              'ÉCARTS',
              '$gaps',
              color: gaps > 0 ? AppColors.warning : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.eyebrow.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.metric.copyWith(fontSize: 18, color: color),
          ),
        ],
      ),
    );
  }
}
