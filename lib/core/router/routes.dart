abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register'; // ← ADD
  static const cameraPermission = '/camera-permission';

  static const shell = '/app';
  static const dashboard = '/app/dashboard';
  static const scanner = '/app/scanner';
  static const cycles = '/app/cycles';
  static const cyclesCreate = '/app/cycles/create';
  static String cyclesDetail(String id) => '/app/cycles/$id';
  static String cyclesItems(String id) => '/app/cycles/$id/items';
  static String cyclesControlTests(String id) =>
      '/app/cycles/$id/control-tests';
  static String cyclesAttachments(String id) => '/app/cycles/$id/attachments';
  static String cyclesRelease(String id) => '/app/cycles/$id/release';

  static const alerts = '/app/alerts';
  static const stock = '/app/stock';
  static const stockIssue = '/app/stock/issue';
  static const stockAdjust = '/app/stock/adjust';
  static const stockTransfer = '/app/stock/transfer';

  static const purchases = '/app/purchases';
  static String purchaseDetail(String id) => '/app/purchases/$id';
  static String goodsReceipt(String id) => '/app/purchases/$id/receive';
  static String receiptPhoto(String id) => '/app/purchases/$id/receive/photo';

  static String labelsDetail(String code) => '/app/labels/$code';
  static String labelsBlocked(String code) => '/app/labels/$code/blocked';
  static String labelsUsage(String labelId) => '/app/labels/$labelId/usage';

  static const patients = '/app/patients/search';
  static const audit = '/app/audit';

  static const settings = '/app/settings';
  static const about = '/app/about';

  static const sync = '/app/sync';
}
