import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/inventory_count_data.dart';
import '../../data/models/stock_option.dart';
import '../../data/repositories/inventory_count_repository.dart';
import '../../data/repositories/stock_repository.dart';

StatusTone inventoryStatusTone(InventoryCountSummary s) => s.isOpen
    ? StatusTone.info
    : s.isClosed
    ? StatusTone.success
    : StatusTone.neutral;

String inventoryStatusLabel(InventoryCountSummary s) => s.isOpen
    ? 'En cours'
    : s.isClosed
    ? 'Terminé'
    : 'Annulé';

/// The inventory sessions ("inventaire"), newest first. Anyone who can see
/// stock sees them; only whoever may move stock can open one.
class InventoryCountListScreen extends StatefulWidget {
  const InventoryCountListScreen({super.key});

  @override
  State<InventoryCountListScreen> createState() =>
      _InventoryCountListScreenState();
}

class _InventoryCountListScreenState extends State<InventoryCountListScreen> {
  final _items = <InventoryCountSummary>[];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _status; // null = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final page = await getIt<InventoryCountRepository>().list();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
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

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await getIt<InventoryCountRepository>().list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openNew() async {
    final created = await showModalBottomSheet<InventoryCountDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const InventoryCountOpenSheet(),
    );
    if (created == null || !mounted) return;
    await context.push(Routes.inventoryCount(created.summary.id));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Inventaires'),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _openNew,
              icon: const Icon(Icons.add),
              label: const Text('Nouvel inventaire'),
            )
          : null,
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView(message: 'Chargement...');
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyView(
        title: 'Aucun inventaire',
        message:
            'Un inventaire compare ce qui est sur l\'étagère avec le stock '
            'enregistré, emplacement par emplacement.',
        icon: Icons.fact_check_outlined,
      );
    }
    int count(String s) => _items.where((i) => i.status == s).length;
    final shown =
        _status == null ? _items : _items.where((i) => i.status == _status).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              'Un inventaire compare ce qui est sur l\'étagère avec le stock '
              'enregistré, emplacement par emplacement.',
              style: AppTypography.caption,
            ),
          ),
          FilterChipRow<String>(
            selected: _status,
            onSelected: (s) => setState(() => _status = s),
            options: [
              FilterChipOption(
                value: null,
                icon: Icons.fact_check_outlined,
                label: 'Tous (${_items.length})',
              ),
              FilterChipOption(
                value: 'open',
                dotColor: AppColors.warning,
                label: 'En cours (${count('open')})',
              ),
              FilterChipOption(
                value: 'closed',
                dotColor: AppColors.success,
                label: 'Clôturés (${count('closed')})',
              ),
              FilterChipOption(
                value: 'cancelled',
                dotColor: AppColors.textTertiary,
                label: 'Annulés (${count('cancelled')})',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: EmptyView(
                title: 'Aucun inventaire',
                message: 'Aucun inventaire ne correspond à ce filtre.',
                icon: Icons.search_off_outlined,
              ),
            ),
          for (final s in shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: AppCard(
                onTap: () async {
                  await context.push(Routes.inventoryCount(s.id));
                  if (mounted) _load();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.openedAt != null)
                                Text(
                                  AppDateFormatter.dateTime(
                                    s.openedAt!.toLocal(),
                                  ).toUpperCase(),
                                  style: AppTypography.eyebrow,
                                ),
                              const SizedBox(height: 2),
                              Text(
                                s.locationName,
                                style: AppTypography.cardTitle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(
                          label: inventoryStatusLabel(s),
                          tone: inventoryStatusTone(s),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWell,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Row(
                        children: [
                          _InvFact(
                            label: 'LOTS COMPTÉS',
                            value: '${s.linesCount}',
                          ),
                          _InvFact(
                            label: 'AJUSTEMENTS',
                            value: s.isClosed ? '${s.adjustmentsCount}' : '—',
                          ),
                          _InvFact(
                            label: s.isClosed ? 'CLÔTURÉ PAR' : 'OUVERT PAR',
                            value: (s.isClosed && s.closedByName != null
                                    ? s.closedByName!
                                    : s.openedByName)
                                .trim()
                                .isEmpty
                                ? '—'
                                : (s.isClosed && s.closedByName != null
                                    ? s.closedByName!
                                    : s.openedByName),
                          ),
                        ],
                      ),
                    ),
                    if ((s.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        s.note!.trim(),
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (s.isCancelled &&
                        (s.cancelReason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Motif d\'annulation : ${s.cancelReason!.trim()}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_cursor != null)
            Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Chargement...' : 'Voir plus'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvFact extends StatelessWidget {
  final String label;
  final String value;
  const _InvFact({required this.label, required this.value});

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
            style: AppTypography.bodyStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Picks the place to count (and an optional note), opens the session on the
/// server and returns it.
class InventoryCountOpenSheet extends StatefulWidget {
  const InventoryCountOpenSheet({super.key});

  @override
  State<InventoryCountOpenSheet> createState() =>
      _InventoryCountOpenSheetState();
}

class _InventoryCountOpenSheetState extends State<InventoryCountOpenSheet> {
  final _note = TextEditingController();
  List<StockOption>? _locations;
  String? _locationId;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final options = await getIt<StockRepository>().listOptions(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => _locations = options.locations);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorMessage.from(e));
    }
  }

  Future<void> _submit() async {
    final id = _locationId;
    if (id == null) {
      setState(() => _error = 'Choisissez l\'emplacement à compter.');
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await getIt<InventoryCountRepository>().open(
        locationId: id,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = _locations;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderMedium,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Nouvel inventaire',
                      style: AppTypography.pageTitle),
                  const SizedBox(height: 2),
                  const Text(
                    'Comptez ce qui est réellement sur l\'étagère : l\'écart '
                    'avec le stock enregistré est corrigé à la clôture.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Emplacement',
                    trailing:
                        const Text('Requis', style: AppTypography.caption),
                    children: [
                      if (locations == null && _error == null)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (locations != null && locations.isEmpty)
                        const Text(
                          'Aucun emplacement actif. Créez-en un depuis le site web.',
                        )
                      else if (locations != null)
                        AppDropdown<String>(
                          key: const ValueKey('inventory_location'),
                          label: 'Emplacement à compter *',
                          value: _locationId,
                          options: locations
                              .map((l) =>
                                  AppDropdownOption(value: l.id, label: l.label))
                              .toList(),
                          onChanged: (v) => setState(() => _locationId = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FormCard(
                    title: 'Note',
                    trailing:
                        const Text('Facultatif', style: AppTypography.caption),
                    children: [
                      AppTextArea(
                        label: 'Note (optionnelle)',
                        controller: _note,
                        maxLines: 2,
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      key: const ValueKey('inventory_open_error'),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          PinnedFooter(
            child: PrimaryButton(
              label: 'Ouvrir l\'inventaire',
              isLoading: _submitting,
              onPressed: _submitting || locations == null ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
