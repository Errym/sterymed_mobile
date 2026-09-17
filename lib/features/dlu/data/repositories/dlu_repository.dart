import '../../../../core/cache/cache.dart';
import '../datasources/dlu_remote_datasource.dart';
import '../models/dlu_rule_data.dart';

class DluRepository {
  final DluRemoteDatasource _remote;
  final AppCache _cache;

  DluRepository(this._remote, this._cache);

  Future<List<DluRuleData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<DluRuleData>>('dlu_rules');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('dlu_rules', fresh);
    return fresh;
  }
}
