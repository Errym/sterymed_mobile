import 'package:dio/dio.dart';

import '../../../../core/cache/cache.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/network/cursor_page.dart';
import '../models/practitioner_option.dart';

/// Practitioners the server accepts on clinical records. The list comes from the
/// server so the app offers exactly the people the server will accept: the same
/// rule validates a create or update, and the two cannot drift apart.
class PractitionerRepository {
  static const _cacheKey = 'practitioners';
  static const _maxPages = 20;

  final Dio _dio;
  final AppCache _cache;

  PractitionerRepository(this._dio, this._cache);

  /// Every eligible practitioner, name order. Cached briefly per user/practice.
  Future<List<PractitionerOption>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<List<PractitionerOption>>(_cacheKey);
      if (cached != null) return cached;
    }
    try {
      final result = <PractitionerOption>[];
      String? cursor;
      for (var page = 0; page < _maxPages; page++) {
        final res = await _dio.get(
          ApiEndpoints.practitioners,
          queryParameters: {'limit': 100, if (cursor != null) 'cursor': cursor},
        );
        final raw = res.data;
        if (raw is! Map || raw['data'] is! List) break;
        result.addAll(
          (raw['data'] as List).whereType<Map>().map(
            (e) => PractitionerOption.fromJson(e.cast<String, dynamic>()),
          ),
        );
        cursor = CursorPage.cursorFromMeta(raw.cast<String, dynamic>());
        if (cursor == null) break;
      }
      _cache.put(_cacheKey, result);
      return result;
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
