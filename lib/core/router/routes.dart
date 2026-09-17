abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const cameraPermission = '/camera-permission';

  static const dashboard = '/app/dashboard';
  static const scanner = '/app/scanner';
  static const cycles = '/app/cycles';
  static const alerts = '/app/alerts';
  static const settings = '/app/settings';

  static const cyclesCreate = '/app/cycles/create';
  static String cyclesDetail(String id) => '/app/cycles/$id';
  static String cyclesItems(String id) => '/app/cycles/$id/items';
  static String cyclesControlTests(String id) => '/app/cycles/$id/control-tests';
  static String cyclesAttachments(String id) => '/app/cycles/$id/attachments';
  static String cyclesRelease(String id) => '/app/cycles/$id/release';

  static const stock = '/app/stock';
  static const stockIssue = '/app/stock/issue';
  static const stockAdjust = '/app/stock/adjust';
  static const stockTransfer = '/app/stock/transfer';

  static String labelsDetail(String code) => '/app/labels/$code';
  static String labelsBlocked(String code) => '/app/labels/$code/blocked';
  static String labelsUsage(String labelId) => '/app/labels/$labelId/usage';

  static const patients = '/app/patients';
  static const audit = '/app/audit';
  static const team = '/app/team';
  static String teamDetail(String id) => '/app/team/$id';
  static const sites = '/app/sites';
  static const nonConformities = '/app/non-conformities';
  static const dataExports = '/app/data-exports';
  static const sync = '/app/sync';
  static const about = '/app/about';
}
