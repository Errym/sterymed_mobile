import 'dart:typed_data';

import '../../../../core/cache/cache.dart';
import '../../../../core/network/cursor_page.dart';
import '../datasources/prosthetic_remote_datasource.dart';
import '../models/laboratory_data.dart';
import '../models/prosthetic_case_attachment_data.dart';
import '../models/prosthetic_case_data.dart';
import '../models/prosthetic_case_status_history_data.dart';
import '../models/prosthetic_dashboard_data.dart';
import '../models/prosthetic_summary_data.dart';

class ProstheticRepository {
  final ProstheticRemoteDatasource _remote;
  final AppCache _cache;

  ProstheticRepository(this._remote, this._cache);

  Future<ProstheticDashboardData> dashboard({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<ProstheticDashboardData>('prosthetic_dashboard');
      if (cached != null) return cached;
    }
    final fresh = await _remote.dashboard();
    _cache.put('prosthetic_dashboard', fresh);
    return fresh;
  }

  Future<CursorPage<ProstheticCaseData>> list({
    String? patientReference,
    String? practitionerId,
    String? laboratoryId,
    String? workType,
    String? status,
    String? from,
    String? to,
    String? scope,
    String? cursor,
  }) =>
      _remote.list(
        cursor: cursor,
        patientReference: patientReference,
        practitionerId: practitionerId,
        laboratoryId: laboratoryId,
        workType: workType,
        status: status,
        from: from,
        to: to,
        scope: scope,
      );

  /// Exact server-side total for a filter/scope set (and, for the waiting
  /// set, the aging buckets). Counted over the whole result.
  Future<ProstheticSummaryData> summary({
    String? patientReference,
    String? practitionerId,
    String? laboratoryId,
    String? workType,
    String? status,
    String? from,
    String? to,
    String? scope,
  }) =>
      _remote.summary(
        patientReference: patientReference,
        practitionerId: practitionerId,
        laboratoryId: laboratoryId,
        workType: workType,
        status: status,
        from: from,
        to: to,
        scope: scope,
      );

  Future<CursorPage<ProstheticCaseData>> waitingForPlacement({
    String? cursor,
    String? aging,
  }) =>
      _remote.waitingForPlacement(cursor: cursor, aging: aging);

  Future<ProstheticCaseData> show(String id) => _remote.show(id);

  Future<ProstheticCaseData> create(Map<String, dynamic> data) async {
    final case_ = await _remote.create(data);
    _cache.invalidate('prosthetic_dashboard');
    return case_;
  }

  Future<ProstheticCaseData> update(String id, Map<String, dynamic> data) async {
    final case_ = await _remote.update(id, data);
    _cache.invalidate('prosthetic_dashboard');
    return case_;
  }

  Future<ProstheticCaseData> changeStatus(
    String id, {
    required String status,
    String? note,
    String? plannedPlacementDate,
  }) async {
    final case_ = await _remote.changeStatus(
      id,
      status: status,
      note: note,
      plannedPlacementDate: plannedPlacementDate,
    );
    _cache.invalidate('prosthetic_dashboard');
    return case_;
  }

  Future<List<ProstheticCaseStatusHistoryData>> statusHistory(String id) =>
      _remote.statusHistory(id);

  Future<List<ProstheticCaseAttachmentData>> listAttachments(String id) =>
      _remote.listAttachments(id);

  Future<ProstheticCaseAttachmentData> uploadAttachment({
    required String caseId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    void Function(int sent, int total)? onProgress,
  }) =>
      _remote.uploadAttachment(
        caseId: caseId,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        onProgress: onProgress,
      );

  Future<void> deleteAttachment(String caseId, String attachmentId) =>
      _remote.deleteAttachment(caseId, attachmentId);

  Future<List<LaboratoryData>> listLaboratories({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<LaboratoryData>>('prosthetic_laboratories');
      if (cached != null) return cached;
    }
    final fresh = await _remote.listLaboratories();
    _cache.put('prosthetic_laboratories', fresh);
    return fresh;
  }

  Future<LaboratoryData> createLaboratory(Map<String, dynamic> data) async {
    final lab = await _remote.createLaboratory(data);
    _cache.invalidate('prosthetic_laboratories');
    return lab;
  }

  Future<LaboratoryData> updateLaboratory(String id, Map<String, dynamic> data) async {
    final lab = await _remote.updateLaboratory(id, data);
    _cache.invalidate('prosthetic_laboratories');
    return lab;
  }
}
