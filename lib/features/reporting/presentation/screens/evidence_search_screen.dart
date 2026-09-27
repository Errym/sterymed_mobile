import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/inputs/app_date_picker.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/cursor_paginated_list.dart';
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

  @override
  void dispose() {
    _patientCtrl.dispose();
    _cycleCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  void _search(BuildContext context) {
    context.read<EvidenceSearchBloc>().add(SearchEvidence(
          patientReference:
              _patientCtrl.text.trim().isEmpty ? null : _patientCtrl.text.trim(),
          cycleNumber: int.tryParse(_cycleCtrl.text.trim()),
          batchNumber:
              _batchCtrl.text.trim().isEmpty ? null : _batchCtrl.text.trim(),
          from: _from,
          to: _to,
        ));
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
          Padding(
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
                const SizedBox(height: AppSpacing.md),
                Row(
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
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Expanded(
            child: BlocBuilder<EvidenceSearchBloc, EvidenceSearchState>(
              builder: (context, state) {
                if (!state.hasSearched) {
                  return const EmptyView(
                    title: 'Lancez une recherche',
                    message: 'Renseignez au moins un filtre pour retrouver '
                        'la chaîne complète pochette → cycle → appareil → '
                        'praticien → patient.',
                    icon: Icons.fact_check_outlined,
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
                  onLoadMore: () async =>
                      context.read<EvidenceSearchBloc>().add(
                            const LoadMoreEvidence(),
                          ),
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

class _EvidenceTile extends StatelessWidget {
  final EvidenceSearchResultData result;
  const _EvidenceTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cycle N°${result.cycleNumber} · ${result.deviceName}',
                  style: AppTypography.bodyStrong,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(result.usedAt),
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.siteName}'
            '${result.batchNumber != null ? ' · Lot ${result.batchNumber}' : ''}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(result.procedure, style: AppTypography.body),
          const SizedBox(height: 2),
          Text(
            'Patient ${result.patientReference} · ${result.practitionerName}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 2),
          Text(
            'Opérateur cycle : ${result.operatorName}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
