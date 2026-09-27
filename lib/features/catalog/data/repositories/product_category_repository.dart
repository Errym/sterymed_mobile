import '../../../../core/cache/cache.dart';
import '../datasources/product_category_datasource.dart';
import '../models/product_category_data.dart';

class ProductCategoryRepository {
  final ProductCategoryDatasource _remote;
  final AppCache _cache;

  ProductCategoryRepository(this._remote, this._cache);

  Future<List<ProductCategoryData>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached =
          _cache.get<List<ProductCategoryData>>('product_categories');
      if (cached != null) return cached;
    }
    final fresh = await _remote.list();
    _cache.put('product_categories', fresh);
    return fresh;
  }
}
