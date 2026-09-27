import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/cycle_item_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../widgets/cycle_item_row.dart';

class CycleItemsScreen extends StatefulWidget {
  final String cycleId;
  const CycleItemsScreen({super.key, required this.cycleId});

  @override
  State<CycleItemsScreen> createState() => _CycleItemsScreenState();
}

class _CycleItemsScreenState extends State<CycleItemsScreen> {
  List<CycleItemData> _items = [];
  bool _loading = true;
  String? _error;

  bool get _canManage => getIt<SessionStore>().hasPermission('cycles.manage');

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
      final items =
          await context.read<CycleRepository>().listItems(widget.cycleId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _add() async {
    final descCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ajouter un instrument'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(label: 'Description', controller: descCtrl),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Lot (optionnel)',
                controller: batchCtrl,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      await context.read<CycleRepository>().addItem(widget.cycleId, {
        'description': descCtrl.text.trim(),
        if (batchCtrl.text.trim().isNotEmpty) 'batch_id': batchCtrl.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.show(context, 'Instrument ajouté.', kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      descCtrl.dispose();
      batchCtrl.dispose();
    }
  }

  Future<void> _delete(CycleItemData item) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cet instrument ?',
      message: item.description,
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<CycleRepository>().deleteItem(widget.cycleId, item.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Instrument supprimé.',
          kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyView(
        title: 'Aucun instrument',
        message: 'Ajoutez les instruments du cycle.',
        icon: Icons.inventory_2_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var i = 0; i < _items.length; i++)
            AnimatedListItem(
              index: i,
              child: CycleItemRow(
                item: _items[i],
                onDelete: _canManage ? () => _delete(_items[i]) : null,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Instruments'),
      body: _buildBody(),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }
}
