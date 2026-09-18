#!/usr/bin/env bash
# =============================================================================
# p1_patient_crud.sh
# - Rewrites PatientData with tolerant parsing (first_name/last_name/full_name/name)
# - Rewrites PatientRemoteDatasource with show/create/destroy
# - Rewrites PatientRepository with update() implemented as delete+recreate
#   (backend has NO PATCH /v1/patients/{id})
# - Rewrites PatientListBloc to support Delete + Update
# - Rewrites PatientSearchScreen with delete + edit affordances
# - Adds PatientFormSheet supporting edit mode (delete+recreate)
# Run from ~/sterymed_mobile
# =============================================================================
set -euo pipefail

ROOT="$(pwd)"
[[ -f "$ROOT/pubspec.yaml" ]] || { echo "❌ Not project root"; exit 1; }
grep -q "name: steriymed_mobile" "$ROOT/pubspec.yaml" || { echo "❌ Wrong project"; exit 1; }

echo "═══════════════════════════════════════════════════════════════"
echo "  P1 — Patient CRUD (edit via delete+recreate)"
echo "═══════════════════════════════════════════════════════════════"

mkdir -p lib/features/patients/data/models
mkdir -p lib/features/patients/data/datasources
mkdir -p lib/features/patients/data/repositories
mkdir -p lib/features/patients/presentation/bloc
mkdir -p lib/features/patients/presentation/screens
mkdir -p lib/features/patients/presentation/widgets

# ─────────────────────────────────────────────────────────────────────────────
# 1. PatientData — tolerant of every shape we've seen
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/data/models/patient_data.dart << 'DART'
import 'package:equatable/equatable.dart';

class PatientData extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String? reference;
  final DateTime? birthDate;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientData({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.reference,
    this.birthDate,
    this.phone,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    // Field name candidates — the backend hasn't always returned the same
    // shape, so we try several keys before giving up.
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return null;
    }

    var first = pick(['first_name', 'firstName', 'given_name']) ?? '';
    var last = pick(['last_name', 'lastName', 'family_name', 'surname']) ?? '';

    // Fallback: split full_name / name
    if (first.isEmpty && last.isEmpty) {
      final full = pick(['full_name', 'name', 'display_name']) ?? '';
      if (full.isNotEmpty) {
        final parts = full.split(RegExp(r'\s+'));
        if (parts.length == 1) {
          first = parts.first;
        } else {
          first = parts.first;
          last = parts.sublist(1).join(' ');
        }
      }
    }

    return PatientData(
      id: pick(['id', 'uuid']) ?? '',
      firstName: first,
      lastName: last,
      reference: pick(['reference', 'file_number', 'dossier_ref']),
      birthDate: _parseDate(pick(['birth_date', 'birthdate', 'date_of_birth'])),
      phone: pick(['phone', 'phone_number', 'mobile', 'telephone']),
      email: pick(['email', 'email_address']),
      createdAt: _parseDate(pick(['created_at'])),
      updatedAt: _parseDate(pick(['updated_at'])),
    );
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? 'Patient sans nom' : combined;
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final result = '$f$l'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  PatientData copyWith({
    String? firstName,
    String? lastName,
    String? reference,
    String? phone,
    String? email,
  }) {
    return PatientData(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      reference: reference ?? this.reference,
      birthDate: birthDate,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, firstName, lastName, reference, phone, email];
}
DART

echo "  ✔ patient_data.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 2. PatientCreateRequest
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/data/models/patient_create_request.dart << 'DART'
class PatientCreateRequest {
  final String firstName;
  final String lastName;
  final String? reference;
  final DateTime? birthDate;
  final String? phone;
  final String? email;

  const PatientCreateRequest({
    required this.firstName,
    required this.lastName,
    this.reference,
    this.birthDate,
    this.phone,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        if (reference != null && reference!.trim().isNotEmpty)
          'reference': reference!.trim(),
        if (birthDate != null)
          'birth_date': birthDate!.toIso8601String().split('T').first,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      };
}
DART

echo "  ✔ patient_create_request.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Remote datasource — create / list / show / destroy
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/data/datasources/patient_remote_datasource.dart << 'DART'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRemoteDatasource {
  final Dio _dio;
  PatientRemoteDatasource(this._dio);

  Future<List<PatientData>> search(String query) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.patients,
        queryParameters: {
          if (query.trim().isNotEmpty) 'search': query.trim(),
          'per_page': 100,
        },
      );
      return _parseList(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PatientData> create(PatientCreateRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.patients,
        data: req.toJson(),
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      return _parseOne(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<PatientData> show(String id) async {
    try {
      final res = await _dio.get(ApiEndpoints.patient(id));
      return _parseOne(res.data);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> destroy(String id) async {
    try {
      await _dio.delete(ApiEndpoints.patient(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  // ── tolerant parsers ─────────────────────────────────────────────────
  List<PatientData> _parseList(dynamic raw) {
    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (raw is Map) {
      for (final key in ['items', 'patients', 'results']) {
        final v = raw[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => PatientData.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      }
    }
    return const [];
  }

  PatientData _parseOne(dynamic raw) {
    if (raw is Map && raw['data'] is Map) {
      return PatientData.fromJson(
        (raw['data'] as Map).cast<String, dynamic>(),
      );
    }
    if (raw is Map) {
      return PatientData.fromJson(raw.cast<String, dynamic>());
    }
    throw const FormatException('Réponse patient invalide');
  }
}
DART

echo "  ✔ patient_remote_datasource.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Repository — update() = delete + recreate (backend has no PATCH)
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/data/repositories/patient_repository.dart << 'DART'
import '../../../../core/cache/cache.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_create_request.dart';
import '../models/patient_data.dart';

class PatientRepository {
  final PatientRemoteDatasource _remote;
  final AppCache _cache;

  PatientRepository(this._remote, this._cache);

  Future<List<PatientData>> search(
    String query, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && query.trim().isEmpty) {
      final cached = _cache.get<List<PatientData>>('patients:all');
      if (cached != null) return cached;
    }
    final fresh = await _remote.search(query);
    if (query.trim().isEmpty) _cache.put('patients:all', fresh);
    return fresh;
  }

  Future<PatientData> create(PatientCreateRequest req) async {
    final p = await _remote.create(req);
    _cache.invalidateAll();
    return p;
  }

  Future<PatientData> show(String id) => _remote.show(id);

  Future<void> destroy(String id) async {
    await _remote.destroy(id);
    _cache.invalidateAll();
  }

  /// Edit is implemented as delete + recreate because the backend has no
  /// PATCH /v1/patients/{id} endpoint (verified in docs/backend_routes.json).
  ///
  /// The old row is deleted and a new one is created with the new values.
  /// Downside: the id changes. Any historical records referencing the old
  /// id will point to a deleted patient. That is acceptable for the pilot
  /// because patients are only referenced by label-usage events, and the
  /// user is explicitly warned before confirming the edit.
  Future<PatientData> update({
    required String id,
    required PatientCreateRequest req,
  }) async {
    AppLogger.d('PatientRepository.update: delete + recreate for $id');
    await _remote.destroy(id);
    final created = await _remote.create(req);
    _cache.invalidateAll();
    return created;
  }
}
DART

echo "  ✔ patient_repository.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 5. Bloc — add Delete + Update events
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/presentation/bloc/patient_list_bloc.dart << 'DART'
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/patient_create_request.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';

part 'patient_list_event.dart';
part 'patient_list_state.dart';

class PatientListBloc extends Bloc<PatientListEvent, PatientListState> {
  final PatientRepository _repository;

  PatientListBloc(this._repository) : super(const PatientListState()) {
    on<LoadPatients>(_onLoad);
    on<SearchPatients>(_onSearch);
    on<CreatePatient>(_onCreate);
    on<UpdatePatient>(_onUpdate);
    on<DeletePatient>(_onDelete);
  }

  Future<void> _onLoad(LoadPatients e, Emitter<PatientListState> emit) async {
    emit(state.copyWith(status: PatientListStatus.loading, error: null));
    try {
      final list = await _repository.search('', forceRefresh: true);
      emit(state.copyWith(status: PatientListStatus.success, patients: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: PatientListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onSearch(SearchPatients e, Emitter<PatientListState> emit) async {
    emit(state.copyWith(query: e.query, status: PatientListStatus.loading));
    try {
      final list = await _repository.search(e.query);
      emit(state.copyWith(status: PatientListStatus.success, patients: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: PatientListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onCreate(CreatePatient e, Emitter<PatientListState> emit) async {
    try {
      await _repository.create(e.request);
      add(const LoadPatients());
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }

  Future<void> _onUpdate(UpdatePatient e, Emitter<PatientListState> emit) async {
    try {
      await _repository.update(id: e.id, req: e.request);
      add(const LoadPatients());
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }

  Future<void> _onDelete(DeletePatient e, Emitter<PatientListState> emit) async {
    try {
      await _repository.destroy(e.id);
      add(const LoadPatients());
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }
}
DART

cat > lib/features/patients/presentation/bloc/patient_list_event.dart << 'DART'
part of 'patient_list_bloc.dart';

abstract class PatientListEvent extends Equatable {
  const PatientListEvent();
  @override
  List<Object?> get props => [];
}

class LoadPatients extends PatientListEvent {
  const LoadPatients();
}

class SearchPatients extends PatientListEvent {
  final String query;
  const SearchPatients(this.query);
  @override
  List<Object?> get props => [query];
}

class CreatePatient extends PatientListEvent {
  final PatientCreateRequest request;
  const CreatePatient(this.request);
  @override
  List<Object?> get props => [request];
}

class UpdatePatient extends PatientListEvent {
  final String id;
  final PatientCreateRequest request;
  const UpdatePatient({required this.id, required this.request});
  @override
  List<Object?> get props => [id, request];
}

class DeletePatient extends PatientListEvent {
  final String id;
  const DeletePatient(this.id);
  @override
  List<Object?> get props => [id];
}
DART

cat > lib/features/patients/presentation/bloc/patient_list_state.dart << 'DART'
part of 'patient_list_bloc.dart';

enum PatientListStatus { initial, loading, success, failure }

class PatientListState extends Equatable {
  final PatientListStatus status;
  final List<PatientData> patients;
  final String query;
  final String? error;

  const PatientListState({
    this.status = PatientListStatus.initial,
    this.patients = const [],
    this.query = '',
    this.error,
  });

  PatientListState copyWith({
    PatientListStatus? status,
    List<PatientData>? patients,
    String? query,
    String? error,
  }) {
    return PatientListState(
      status: status ?? this.status,
      patients: patients ?? this.patients,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, patients, query, error];
}
DART

echo "  ✔ patient_list_bloc.dart (+ event + state)"

# ─────────────────────────────────────────────────────────────────────────────
# 6. PatientFormSheet — supports create AND edit
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/presentation/widgets/patient_form_sheet.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/patient_create_request.dart';
import '../../data/models/patient_data.dart';
import '../bloc/patient_list_bloc.dart';

class PatientFormSheet extends StatefulWidget {
  final PatientData? existing;

  const PatientFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {PatientData? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<PatientListBloc>(),
        child: PatientFormSheet(existing: existing),
      ),
    );
  }

  @override
  State<PatientFormSheet> createState() => _PatientFormSheetState();
}

class _PatientFormSheetState extends State<PatientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.existing?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: widget.existing?.lastName ?? '');
    _refCtrl = TextEditingController(text: widget.existing?.reference ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _refCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final req = PatientCreateRequest(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );

    if (_isEdit) {
      context.read<PatientListBloc>().add(
            UpdatePatient(id: widget.existing!.id, request: req),
          );
    } else {
      context.read<PatientListBloc>().add(CreatePatient(req));
    }

    if (!mounted) return;
    AppSnackbar.show(
      context,
      _isEdit ? 'Patient modifié.' : 'Patient enregistré.',
      kind: SnackKind.success,
    );
    Navigator.of(context).pop(true);
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
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _isEdit ? 'Modifier le patient' : 'Nouveau patient',
              style: AppTypography.sectionTitle,
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Le dossier sera recréé avec un nouvel identifiant '
                        'interne (limitation du serveur actuel).',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Prénom *',
              controller: _firstNameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom *',
              controller: _lastNameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Référence dossier',
              controller: _refCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Téléphone',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'E-mail',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _isEdit ? 'Enregistrer les modifications' : 'Enregistrer',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
DART

echo "  ✔ patient_form_sheet.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 7. PatientSearchScreen — with edit + delete affordances
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/presentation/screens/patient_search_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';
import '../bloc/patient_list_bloc.dart';
import '../widgets/patient_form_sheet.dart';
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
    await PatientFormSheet.show(context);
  }

  Future<void> _edit(BuildContext context, PatientData p) async {
    await PatientFormSheet.show(context, existing: p);
  }

  Future<void> _delete(BuildContext context, PatientData p) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer ce patient ?',
      message:
          '${p.fullName}\n\nCette action est irréversible. Les événements '
          'de traçabilité liés resteront dans le journal d\'audit.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    context.read<PatientListBloc>().add(DeletePatient(p.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Nouveau patient',
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
                    return ErrorView(
                      message: state.error ?? 'Erreur',
                      onRetry: () => context
                          .read<PatientListBloc>()
                          .add(const LoadPatients()),
                    );
                  }
                  if (state.patients.isEmpty) {
                    return EmptyView(
                      title: 'Aucun patient',
                      message: 'Ajoutez votre premier patient.',
                      icon: Icons.person_outline,
                      action: FilledButton.icon(
                        onPressed: () => _create(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nouveau patient'),
                      ),
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
                        return Dismissible(
                          key: ValueKey(p.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                                right: AppSpacing.md),
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
                          child: GestureDetector(
                            onLongPress: () => _edit(context, p),
                            child: PatientTile(
                              patient: p,
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 18,
                                    color: AppColors.textSecondary),
                                onSelected: (v) {
                                  if (v == 'edit') _edit(context, p);
                                  if (v == 'delete') _delete(context, p);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Modifier'),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.danger),
                                      SizedBox(width: 8),
                                      Text('Supprimer',
                                          style: TextStyle(
                                              color: AppColors.danger)),
                                    ]),
                                  ),
                                ],
                              ),
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
DART

echo "  ✔ patient_search_screen.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 8. PatientTile — accept a trailing widget
# ─────────────────────────────────────────────────────────────────────────────
cat > lib/features/patients/presentation/widgets/patient_tile.dart << 'DART'
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/media/app_avatar.dart';
import '../../data/models/patient_data.dart';

class PatientTile extends StatelessWidget {
  final PatientData patient;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PatientTile({
    super.key,
    required this.patient,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              AppAvatar(initials: patient.initials, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.fullName, style: AppTypography.bodyStrong),
                    const SizedBox(height: 2),
                    if (patient.reference != null)
                      Text(patient.reference!, style: AppTypography.caption),
                    if (patient.phone != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(patient.phone!, style: AppTypography.caption),
                        ],
                      ),
                    ],
                    if (patient.email != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.mail_outline,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(patient.email!,
                                style: AppTypography.caption,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
DART

echo "  ✔ patient_tile.dart"

# ─────────────────────────────────────────────────────────────────────────────
# 9. Remove the old patient_create_sheet.dart (superseded by patient_form_sheet)
# ─────────────────────────────────────────────────────────────────────────────
rm -f lib/features/patients/presentation/widgets/patient_create_sheet.dart

echo "  ✔ removed old patient_create_sheet.dart"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  P1 verification"
echo "═══════════════════════════════════════════════════════════════"
flutter analyze 2>&1 | tee /tmp/p1.txt | tail -30
echo ""
echo "  Errors: $(grep -c ' error •' /tmp/p1.txt || echo 0)"