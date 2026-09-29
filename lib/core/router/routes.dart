abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const cameraPermission = '/camera-permission';

  // Shell tabs
  static const dashboard = '/app/dashboard';
  static const scanner = '/app/scanner';
  static const cycles = '/app/cycles';
  static const alerts = '/app/alerts';
  static const settings = '/app/settings';

  // Cycles
  static const cyclesCreate = '/app/cycles/create';
  static String cyclesDetail(String id) => '/app/cycles/$id';
  static String cyclesItems(String id) => '/app/cycles/$id/items';
  static String cyclesControlTests(String id) => '/app/cycles/$id/control-tests';
  static String cyclesAttachments(String id) => '/app/cycles/$id/attachments';
  static String cyclesRelease(String id) => '/app/cycles/$id/release';

  // Stock
  static const stock = '/app/stock';
  static const stockIssue = '/app/stock/issue';
  static const stockAdjust = '/app/stock/adjust';
  static const stockTransfer = '/app/stock/transfer';

  // Labels
  static String labelsDetail(String code) => '/app/labels/$code';
  static String labelsBlocked(String code) => '/app/labels/$code/blocked';
  static String labelsUsage(String labelId) => '/app/labels/$labelId/usage';

  // Patients
  static const patients = '/app/patients';

  // Audit
  static const audit = '/app/audit';

  // Team
  static const team = '/app/team';

  // Sites
  static const sites = '/app/sites';
  static String siteLocations(String siteId) => '/app/sites/$siteId/locations';

  // Batches
  static const batches = '/app/batches';

  // Compliance
  static const nonConformities = '/app/non-conformities';

  // Reporting
  static const dataExports = '/app/data-exports';
  static const evidenceSearch = '/app/evidence-search';

  // Sync
  static const sync = '/app/sync';

  // About
  static const about = '/app/about';

  // Catalog
  static const products = '/app/catalog/products';

  // Suppliers
  static const suppliers = '/app/purchases/suppliers';
  static String supplierDetail(String id) =>
      '/app/purchases/suppliers/$id';

  // Purchases
  static const purchases = '/app/purchases';
  static String purchaseDetail(String id) => '/app/purchases/$id';
  static String goodsReceipt(String id) => '/app/purchases/$id/receive';

  // Devices
  static const devices = '/app/devices';
  static String deviceDetail(String id) => '/app/devices/$id';

  // DLU rules
  static const dluRules = '/app/dlu-rules';

  // Prosthetic
  static const prosthetic = '/app/prosthetic';
  static const prostheticCreate = '/app/prosthetic/create';
  static const prostheticWaitingPlacement = '/app/prosthetic/waiting-placement';
  static const prostheticLaboratories = '/app/prosthetic/laboratories';
  static String prostheticDetail(String id) => '/app/prosthetic/$id';
}
