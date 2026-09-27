import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';
import '../bloc/patient_list_bloc.dart';
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

  Future<void> _create(BuildContext context) async {
    // Patients carry no PII — creating one is a single confirmed action,
    // not a form. The backend generates the anonymous reference.
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Nouveau dossier patient',
      message: 'Un dossier anonyme sera créé avec une référence générée '
          'automatiquement. Aucune information personnelle n\'est '
          'enregistrée dans cette application.',
      confirmLabel: 'Créer',
    );
    if (!ok || !context.mounted) return;
    context.read<PatientListBloc>().add(const CreatePatient());
  }

  Future<void> _delete(BuildContext context, PatientData p) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer ce dossier ?',
      message: '${p.reference}\n\nCette action est irréversible. Les événements '
          'de traçabilité liés resteront dans le journal d\'audit.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    context.read<PatientListBloc>().add(DeletePatient(p.id));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('patients.manage');

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.person_add_alt_outlined),
              tooltip: 'Nouveau dossier',
              onPressed: () => _create(context),
            ),
        ],
      ),
      body: BlocListener<PatientListBloc, PatientListState>(
        listenWhen: (p, c) => p.error != c.error && c.error != null,
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppSearchField(
                hint: 'Rechercher par référence...',
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
                    return ErrorView(
                      message: state.error ?? 'Erreur',
                      onRetry: () => context
                          .read<PatientListBloc>()
                          .add(const LoadPatients()),
                    );
                  }
                  if (state.patients.isEmpty) {
                    return EmptyView(
                      title: 'Aucun dossier',
                      message: 'Créez votre premier dossier patient.',
                      icon: Icons.person_outline,
                      action: canManage
                          ? FilledButton.icon(
                              onPressed: () => _create(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Nouveau dossier'),
                            )
                          : null,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => context
                        .read<PatientListBloc>()
                        .add(const LoadPatients()),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.patients.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final p = state.patients[i];
                        return AnimatedListItem(
                          index: i,
                          child: Dismissible(
                            key: ValueKey(p.id),
                            direction: canManage
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                            ),
                            confirmDismiss: (_) async {
                              await _delete(context, p);
                              return false; // bloc will refresh; keep row
                            },
                            child: PatientTile(
                              patient: p,
                              trailing: canManage
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.danger),
                                      onPressed: () => _delete(context, p),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
