import '../datasources/label_remote_datasource.dart';
import '../models/label_scan_result.dart';

class LabelRepository {
  final LabelRemoteDatasource _remote;
  LabelRepository(this._remote);

  Future<LabelScanResult> getByCode(String code) => _remote.fetchByCode(code);

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// The label id carried by a scanned (`urn:steriqore:label:<id>`) or typed
  /// code, or null when [code] does not contain one. No request: a recalled or
  /// expired label can still be the subject of a report even though looking it
  /// up is refused.
  static String? idFromCode(String code) {
    final trimmed = code.trim();
    const prefix = 'urn:steriqore:label:';
    final id = trimmed.startsWith(prefix)
        ? trimmed.substring(prefix.length)
        : trimmed;
    return _uuid.hasMatch(id) ? id.toLowerCase() : null;
  }
}
