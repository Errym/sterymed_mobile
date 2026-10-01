import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../../identity/data/models/practitioner_option.dart';
import '../../../identity/data/repositories/practitioner_repository.dart';
import '../../data/models/laboratory_data.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import '../bloc/prosthetic_case_list_bloc.dart';
import '../widgets/prosthetic_case_tile.dart';

class ProstheticCaseListScreen extends StatelessWidget {
  final String? initialStatus;
  const ProstheticCaseListScreen({super.key, this.initialStatus});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProstheticCaseListBloc(getIt<ProstheticRepository>())
        ..add(FilterProstheticCases(
          ProstheticCaseListFilters(status: initialStatus),
        )),
      child: const _ProstheticCaseListView(),
    );
  }
}

class _ProstheticCaseListView extends StatefulWidget {
  const _ProstheticCaseListView();

  @override
  State<_ProstheticCaseListView> createState() =>
      _ProstheticCaseListViewState();
}

class _ProstheticCaseListViewState extends State<_ProstheticCaseListView> {
  final _searchCtrl = TextEditingController();

  // Loaded once and reused both by the filter sheet's dropdown and by the
  // active-filter-chip row (to show a laboratory's real name, not its id).
  List<LaboratoryData> _laboratories = [];
  // Same idea for practitioners: real names in the dropdown and in the chip.
  List<PractitionerOption> _practitioners = [];

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadLaboratories();
    _loadPractitioners();
  }

  Future<void> _loadPractitioners() async {
    try {
      final people = await getIt<PractitionerRepository>().list();
      if (!mounted) return;
      setState(() => _practitioners = people);
    } catch (_) {
      // Secondary data: the other filters stay usable if this fails.
    }
  }

  String? _practitionerName(String id) {
    for (final p in _practitioners) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  Future<void> _loadLaboratories() async {
    try {
      final labs = await getIt<ProstheticRepository>().listLaboratories();
      if (!mounted) return;
      setState(() => _laboratories = labs);
    } catch (_) {
      // The laboratory filter simply shows no options if this fails — the
      // other 5 filter dimensions remain usable. No blocking error state
      // for a secondary, non-critical dropdown's data source.
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters(BuildContext context, ProstheticCaseListFilters filters) {
    context.read<ProstheticCaseListBloc>().add(FilterProstheticCases(filters));
    // Keep the quick-search box in sync in case the change came from the
    // filter sheet or a chip removal, not the search box itself.
    if (_searchCtrl.text != (filters.patientReference ?? '')) {
      _searchCtrl.text = filters.patientReference ?? '';
    }
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final bloc = context.read<ProstheticCaseListBloc>();
    final result = await showModalBottomSheet<ProstheticCaseListFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _ProstheticFilterSheet(
        initial: bloc.state.filters,
        laboratories: _laboratories,
        practitioners: _practitioners,
      ),
    );
    if (result != null && context.mounted) {
      _applyFilters(context, result);
    }
  }

  String? _laboratoryName(String id) {
    for (final l in _laboratories) {
      if (l.id == id) return l.name;
    }
    return null;
  }

  List<Widget> _activeFilterChips(
    BuildContext context,
    ProstheticCaseListFilters filters,
  ) {
    final chips = <Widget>[];

    void addChip(String label, VoidCallback onRemove) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: Chip(
          label: Text(label, style: AppTypography.caption),
          onDeleted: onRemove,
        ),
      ));
    }

    if (filters.patientReference != null &&
        filters.patientReference!.isNotEmpty) {
      addChip(
        'Patient : ${filters.patientReference}',
        () => _applyFilters(
          context,
          filters.copyWith(clearPatientReference: true),
        ),
      );
    }
    if (filters.practitionerId != null && filters.practitionerId!.isNotEmpty) {
      addChip(
        'Praticien : ${_practitionerName(filters.practitionerId!) ?? 'inconnu'}',
        () => _applyFilters(
          context,
          filters.copyWith(clearPractitionerId: true),
        ),
      );
    }
    if (filters.laboratoryId != null) {
      final name = _laboratoryName(filters.laboratoryId!) ?? filters.laboratoryId!;
      addChip(
        'Laboratoire : $name',
        () => _applyFilters(context, filters.copyWith(clearLaboratoryId: true)),
      );
    }
    if (filters.workType != null) {
      addChip(
        'Type : ${ProstheticWorkType.fromWire(filters.workType!).label}',
        () => _applyFilters(context, filters.copyWith(clearWorkType: true)),
      );
    }
    if (filters.status != null) {
      addChip(
        'Statut : ${ProstheticCaseStatus.fromWire(filters.status!).label}',
        () => _applyFilters(context, filters.copyWith(clearStatus: true)),
      );
    }
    if (filters.from != null) {
      addChip(
        'Du : ${_dateFmt.format(filters.from!)}',
        () => _applyFilters(context, filters.copyWith(clearFrom: true)),
      );
    }
    if (filters.to != null) {
      addChip(
        'Au : ${_dateFmt.format(filters.to!)}',
        () => _applyFilters(context, filters.copyWith(clearTo: true)),
      );
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Dossiers prothétiques',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrer',
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: AppSearchField(
              hint: 'Rechercher par référence patient...',
              controller: _searchCtrl,
              onChanged: (v) => _applyFilters(
                context,
                context.read<ProstheticCaseListBloc>().state.filters.copyWith(
                      patientReference: v.isEmpty ? null : v,
                      clearPatientReference: v.isEmpty,
                    ),
              ),
            ),
          ),
          BlocBuilder<ProstheticCaseListBloc, ProstheticCaseListState>(
            buildWhen: (a, b) => a.filters != b.filters,
            builder: (context, state) {
              if (state.filters.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                ),
                child: Wrap(
                  children: _activeFilterChips(context, state.filters),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<ProstheticCaseListBloc, ProstheticCaseListState>(
              builder: (context, state) {
                return CursorPaginatedList<ProstheticCaseData>(
                  items: state.cases,
                  isLoading: state.status == ProstheticCaseListStatus.loading,
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                  error: state.status == ProstheticCaseListStatus.failure
                      ? (state.error ?? 'Erreur')
                      : null,
                  onRetry: () => context
                      .read<ProstheticCaseListBloc>()
                      .add(const LoadProstheticCases()),
                  onRefresh: () async => context
                      .read<ProstheticCaseListBloc>()
                      .add(const LoadProstheticCases()),
                  onLoadMore: () async => context
                      .read<ProstheticCaseListBloc>()
                      .add(const LoadMoreProstheticCases()),
                  emptyTitle: 'Aucun dossier',
                  emptyMessage: 'Aucun dossier prothétique pour ces filtres.',
                  emptyIcon: Icons.medical_services_outlined,
                  itemBuilder: (context, item, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AnimatedListItem(
                      index: index,
                      child: ProstheticCaseTile(
                        item: item,
                        onTap: () =>
                            context.push(Routes.prostheticDetail(item.id)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProstheticFilterSheet extends StatefulWidget {
  final ProstheticCaseListFilters initial;
  final List<LaboratoryData> laboratories;
  final List<PractitionerOption> practitioners;

  const _ProstheticFilterSheet({
    required this.initial,
    required this.laboratories,
    required this.practitioners,
  });

  @override
  State<_ProstheticFilterSheet> createState() => _ProstheticFilterSheetState();
}

class _ProstheticFilterSheetState extends State<_ProstheticFilterSheet> {
  late final _patientCtrl =
      TextEditingController(text: widget.initial.patientReference ?? '');
  late String? _practitionerId = widget.initial.practitionerId;
  late String? _laboratoryId = widget.initial.laboratoryId;
  late String? _workType = widget.initial.workType;
  late String? _status = widget.initial.status;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;

  @override
  void dispose() {
    _patientCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _patientCtrl.clear();
      _practitionerId = null;
      _laboratoryId = null;
      _workType = null;
      _status = null;
      _from = null;
      _to = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(ProstheticCaseListFilters(
      patientReference:
          _patientCtrl.text.trim().isEmpty ? null : _patientCtrl.text.trim(),
      practitionerId: _practitionerId,
      laboratoryId: _laboratoryId,
      workType: _workType,
      status: _status,
      from: _from,
      to: _to,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrer les dossiers', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              hint: 'Référence patient...',
              controller: _patientCtrl,
              onChanged: null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String?>(
              label: 'Praticien',
              value: _practitionerId,
              options: [
                const AppDropdownOption(
                  value: null,
                  label: 'Tous les praticiens',
                ),
                ...widget.practitioners.map(
                  (p) => AppDropdownOption(value: p.id, label: p.name),
                ),
                // A filter chosen earlier for someone no longer on the list
                // stays visible instead of silently disappearing.
                if (_practitionerId != null &&
                    !widget.practitioners.any((p) => p.id == _practitionerId))
                  AppDropdownOption(
                    value: _practitionerId,
                    label: 'Praticien inconnu',
                  ),
              ],
              onChanged: (v) => setState(() => _practitionerId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String?>(
              label: 'Laboratoire',
              value: _laboratoryId,
              options: [
                const AppDropdownOption(value: null, label: 'Tous les laboratoires'),
                ...widget.laboratories
                    .map((l) => AppDropdownOption(value: l.id, label: l.name)),
              ],
              onChanged: (v) => setState(() => _laboratoryId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String?>(
              label: 'Type de travail',
              value: _workType,
              options: [
                const AppDropdownOption(value: null, label: 'Tous les types'),
                ...ProstheticWorkType.values
                    .map((t) => AppDropdownOption(value: t.wire, label: t.label)),
              ],
              onChanged: (v) => setState(() => _workType = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String?>(
              label: 'Statut',
              value: _status,
              options: [
                const AppDropdownOption(value: null, label: 'Tous les statuts'),
                ...ProstheticCaseStatus.values
                    .where((s) => s != ProstheticCaseStatus.unknown)
                    .map((s) => AppDropdownOption(value: s.wire, label: s.label)),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppDatePicker(
                    label: 'Du',
                    value: _from,
                    lastDate: _to ?? DateTime.now(),
                    onChanged: (d) => setState(() => _from = d),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppDatePicker(
                    label: 'Au',
                    value: _to,
                    firstDate: _from,
                    lastDate: DateTime.now(),
                    onChanged: (d) => setState(() => _to = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Effacer les filtres',
                    isFullWidth: false,
                    onPressed: _clear,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Appliquer',
                    isFullWidth: false,
                    onPressed: _apply,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
