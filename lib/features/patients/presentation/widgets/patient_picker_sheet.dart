import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';
import '../bloc/patient_search_bloc.dart';
import 'patient_tile.dart';

class PatientPickerSheet extends StatelessWidget {
  const PatientPickerSheet({super.key});

  static Future<PatientData?> show(BuildContext context) {
    return showModalBottomSheet<PatientData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider(
        create: (_) => PatientSearchBloc(getIt<PatientRepository>()),
        child: const PatientPickerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sélectionner un patient',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AppSearchField(
                hint: 'Rechercher par nom, prénom...',
                controller: controller,
                autofocus: true,
                onChanged: (q) => context
                    .read<PatientSearchBloc>()
                    .add(PatientSearchQueryChanged(q)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: BlocBuilder<PatientSearchBloc, PatientSearchState>(
                builder: (context, state) {
                  if (state.status == PatientSearchStatus.loading &&
                      state.results.isEmpty) {
                    return const LoadingView();
                  }
                  if (state.status == PatientSearchStatus.failure) {
                    return ErrorView(message: state.error ?? 'Erreur');
                  }
                  if (state.status == PatientSearchStatus.success &&
                      state.results.isEmpty) {
                    return const EmptyView(
                      title: 'Aucun patient',
                      message: 'Essayez une autre recherche.',
                      icon: Icons.person_search_outlined,
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final p = state.results[i];
                      return PatientTile(
                        patient: p,
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
