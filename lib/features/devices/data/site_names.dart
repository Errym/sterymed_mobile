import '../../../di/di.dart';
import '../../sites/data/repositories/site_repository.dart';

/// Site id -> site name, for screens that only receive a site id. A role that
/// may not read sites, or a failed call, simply yields an empty map: the
/// screen then shows no site name rather than a wrong one.
Future<Map<String, String>> loadSiteNames() async {
  try {
    final sites = await getIt<SiteRepository>().list();
    return {for (final s in sites) s.id: s.name};
  } catch (_) {
    return const {};
  }
}
