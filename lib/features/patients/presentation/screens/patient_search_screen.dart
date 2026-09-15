import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../bloc/patient_search_bloc.dart';
import '../widgets/patient_tile.dart';

class PatientSearchScreen extends StatelessWidget {
  const PatientSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => PatientSearchBloc(ctx.read()),
      child: const _PatientSearchView(),
    );
  }
}

class _PatientSearchView extends StatelessWidget {
  const _PatientSearchView();

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Patients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchField(
              hint: 'Rechercher un patient...',
              controller: controller,
              onChanged: (q) => context
                  .read<PatientSearchBloc>()
                  .add(PatientSearchQueryChanged(q)),
            ),
          ),
          Expanded(
            child: BlocBuilder<PatientSearchBloc, PatientSearchState>(
              builder: (context, state) {
                if (state.status == PatientSearchStatus.idle) {
                  return const EmptyView(
                    title: 'Recherchez un patient',
                    message: 'Entrez un nom ou une référence.',
                    icon: Icons.person_search_outlined,
                  );
                }
                if (state.status == PatientSearchStatus.loading &&
                    state.results.isEmpty) {
                  return const LoadingView();
                }
                if (state.status == PatientSearchStatus.failure) {
                  return ErrorView(message: state.error ?? 'Erreur');
                }
                if (state.results.isEmpty) {
                  return const EmptyView(
                    title: 'Aucun patient trouvé',
                    icon: Icons.person_off_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.results.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => PatientTile(patient: state.results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
