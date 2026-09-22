import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items =
          await context.read<CycleRepository>().listItems(widget.cycleId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
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
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Instruments'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyView(
                  title: 'Aucun instrument',
                  message: 'Ajoutez les instruments du cycle.',
                  icon: Icons.inventory_2_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        AnimatedListItem(
                          index: i,
                          child: CycleItemRow(
                            item: _items[i],
                            onDelete: () => _delete(_items[i]),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
