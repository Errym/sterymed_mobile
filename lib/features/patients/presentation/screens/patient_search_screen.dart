import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../data/repositories/patient_repository.dart';
import '../bloc/patient_list_bloc.dart';
import '../widgets/patient_create_sheet.dart';
import '../widgets/patient_tile.dart';

class PatientSearchScreen extends StatelessWidget {
  const PatientSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PatientListBloc(getIt<PatientRepository>())
        ..add(const LoadPatients()),
      child: const _PatientView(),
    );
  }
}

class _PatientView extends StatelessWidget {
  const _PatientView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: () => PatientCreateSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchField(
              hint: 'Rechercher un patient...',
              onChanged: (q) =>
                  context.read<PatientListBloc>().add(SearchPatients(q)),
            ),
          ),
          Expanded(
            child: BlocBuilder<PatientListBloc, PatientListState>(
              builder: (context, state) {
                if (state.status == PatientListStatus.loading &&
                    state.patients.isEmpty) {
                  return const LoadingView();
                }
                if (state.status == PatientListStatus.failure) {
                  return ErrorView(message: state.error ?? 'Erreur');
                }
                if (state.patients.isEmpty) {
                  return const EmptyView(
                    title: 'Aucun patient',
                    message: 'Ajoutez votre premier patient.',
                    icon: Icons.person_outline,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.patients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => PatientTile(patient: state.patients[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
