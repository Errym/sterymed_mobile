import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/files/file_export_service.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/saved_file_sheet.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
import '../../data/models/evidence_filter_query.dart';
import '../../data/models/evidence_search_result_data.dart';
import '../../data/repositories/evidence_search_repository.dart';
import '../bloc/evidence_search_bloc.dart';

/// A compliance inspector's core question — "show me everything for this
/// patient / cycle / batch / date range" — answered against the real
/// pouch → cycle → device → practitioner → procedure → patient chain
/// (`GET /v1/evidence-search`, gated on `usages.view`, universal).
class EvidenceSearchScreen extends StatelessWidget {
  const EvidenceSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EvidenceSearchBloc(getIt<EvidenceSearchRepository>()),
      child: const _EvidenceSearchView(),
    );
  }
}

class _EvidenceSearchView extends StatefulWidget {
  const _EvidenceSearchView();

  @override
  State<_EvidenceSearchView> createState() => _EvidenceSearchViewState();
}

class _EvidenceSearchViewState extends State<_EvidenceSearchView> {
  final _patientCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  bool _exporting = false;

  /// Exports exactly the search on screen (the filters of the LAST search, not
  /// whatever has since been typed into the form), as a CSV the clinic keeps.
  Future<void> _export(EvidenceSearchState state) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final file = await getIt<FileExportService>().saveFromApi(
        ApiEndpoints.evidenceExport,
        query: {
          ...evidenceFilterQuery(
            patientReference: state.patientReference,
            cycleNumber: state.cycleNumber,
            batchNumber: state.batchNumber,
            from: state.from,
            to: state.to,
          ),
          'format': 'csv',
        },
        baseName: 'preuves',
        extension: 'csv',
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      await SavedFileSheet.show(
        context,
        file: file,
        title: 'Export enregistré',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    _patientCtrl.dispose();
    _cycleCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  void _search(BuildContext context) {
    context.read<EvidenceSearchBloc>().add(
      SearchEvidence(
        patientReference: _patientCtrl.text.trim().isEmpty
            ? null
            : _patientCtrl.text.trim(),
        cycleNumber: int.tryParse(_cycleCtrl.text.trim()),
        batchNumber: _batchCtrl.text.trim().isEmpty
            ? null
            : _batchCtrl.text.trim(),
        from: _from,
        to: _to,
      ),
    );
  }

  void _reset(BuildContext context) {
    setState(() {
      _patientCtrl.clear();
      _cycleCtrl.clear();
      _batchCtrl.clear();
      _from = null;
      _to = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Recherche de preuves'),
      body: Column(
        children: [
          // The form scrolls inside at most half the screen: on a small phone,
          // or with the keyboard open, it must never push the results (or
          // itself) off the bottom.
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Filtres'),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Référence patient',
                      controller: _patientCtrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'N° de cycle',
                            controller: _cycleCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppTextField(
                            label: 'N° de lot',
                            controller: _batchCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppDatePicker(
                            label: 'Du',
                            value: _from,
                            lastDate: _to,
                            onChanged: (d) => setState(() => _from = d),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppDatePicker(
                            label: 'Au',
                            value: _to,
                            firstDate: _from,
                            onChanged: (d) => setState(() => _to = d),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Always on screen: the search button must never sit below the fold.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Rechercher',
                    icon: Icons.search,
                    onPressed: () => _search(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => _reset(context),
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          // Bulk export has its own, stricter permission than viewing: hidden
          // (not disabled) for a role that would only get a refusal.
          BlocBuilder<EvidenceSearchBloc, EvidenceSearchState>(
            buildWhen: (a, b) =>
                a.hasSearched != b.hasSearched || a.status != b.status,
            builder: (context, state) {
              final canExport = getIt<SessionStore>().hasPermission(
                'exports.manage',
              );
              if (!canExport ||
                  !state.hasSearched ||
                  state.status != EvidenceSearchStatus.success ||
                  state.results.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    key: const Key('evidence-export-csv'),
                    onPressed: _exporting ? null : () => _export(state),
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(
                      _exporting
                          ? 'Export en cours…'
                          : 'Exporter ces résultats (CSV)',
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: BlocBuilder<EvidenceSearchBloc, EvidenceSearchState>(
              builder: (context, state) {
                if (!state.hasSearched) {
                  // Scrolls so it can never overflow when the form above takes
                  // most of a small screen.
                  return LayoutBuilder(
                    builder: (_, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: const EmptyView(
                          title: 'Lancez une recherche',
                          message:
                              'Renseignez au moins un filtre pour retrouver '
                              'la chaîne complète pochette → cycle → appareil '
                              '→ praticien → patient.',
                          icon: Icons.fact_check_outlined,
                        ),
                      ),
                    ),
                  );
                }
                return CursorPaginatedList<EvidenceSearchResultData>(
                  items: state.results,
                  isLoading: state.status == EvidenceSearchStatus.loading,
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                  error: state.status == EvidenceSearchStatus.failure
                      ? (state.error ?? 'Erreur')
                      : null,
                  onRetry: () => _search(context),
                  onLoadMore: () async => context
                      .read<EvidenceSearchBloc>()
                      .add(const LoadMoreEvidence()),
                  emptyTitle: 'Aucun résultat',
                  emptyMessage: 'Aucune preuve ne correspond à ces filtres.',
                  emptyIcon: Icons.search_off,
                  itemBuilder: (_, r, i) => AnimatedListItem(
                    index: i,
                    child: _EvidenceTile(result: r),
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

/// One recorded use, shown as the chain an inspector follows: the procedure,
/// the patient and practitioner it was for, and the pouch's whole history
/// (batch, cycle, machine, operator) back to the sterilization.
class _EvidenceTile extends StatelessWidget {
  final EvidenceSearchResultData result;
  const _EvidenceTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd/MM/yyyy · HH:mm').format(r.usedAt).toUpperCase(),
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 2),
          Text(
            r.procedure.isEmpty ? 'Utilisation enregistrée' : r.procedure,
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              EntityMark.initials(EntityMark.initialsOf(r.patientReference)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient ${r.patientReference}',
                      style: AppTypography.bodyStrong,
                    ),
                    Text(
                      r.practitionerName,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceWell,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PARCOURS DE LA POCHETTE',
                    style: AppTypography.eyebrow),
                const SizedBox(height: AppSpacing.xs),
                if ((r.batchNumber ?? '').isNotEmpty)
                  DetailRow(Icons.qr_code_2, 'Lot', r.batchNumber!),
                DetailRow(Icons.autorenew, 'Cycle', 'N°${r.cycleNumber}'),
                DetailRow(
                  Icons.precision_manufacturing_outlined,
                  'Appareil',
                  r.deviceName,
                ),
                DetailRow(Icons.business_outlined, 'Site', r.siteName),
                DetailRow(
                  Icons.person_outline,
                  'Opérateur du cycle',
                  r.operatorName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
