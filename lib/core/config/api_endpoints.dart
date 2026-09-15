abstract final class ApiEndpoints {
  static const _v1 = '/v1';

  // Auth
  static const login = '$_v1/auth/login';
  static const register = '$_v1/tenants';
  static const logout = '$_v1/auth/logout';
  static const logoutEverywhere = '$_v1/auth/tokens';
  static const me = '$_v1/me';

  // Dashboard
  static const dashboard = '$_v1/dashboard';

  // Alerts
  static const alerts = '$_v1/alerts';
  static String alertResolve(String id) => '$_v1/alerts/$id/resolve';

  // Labels
  static String labelByCode(String code) => '$_v1/labels/$code';
  static String labelUsage(String labelId) => '$_v1/labels/$labelId/usage';

  // Patients
  static const patients = '$_v1/patients';

  // Cycles
  static const cycles = '$_v1/cycles';
  static String cycle(String id) => '$_v1/cycles/$id';
  static String cycleStart(String id) => '$_v1/cycles/$id/start';
  static String cycleComplete(String id) => '$_v1/cycles/$id/complete';
  static String cycleSubmit(String id) => '$_v1/cycles/$id/submit-for-release';
  static String cycleRelease(String id) => '$_v1/cycles/$id/release';
  static String cycleItems(String id) => '$_v1/cycles/$id/items';
  static String cycleItem(String id, String itemId) =>
      '$_v1/cycles/$id/items/$itemId';
  static String cycleControlTests(String id) => '$_v1/cycles/$id/control-tests';
  static String cycleAttachments(String id) => '$_v1/cycles/$id/attachments';
  static String cycleAttachment(String id, int mediaId) =>
      '$_v1/cycles/$id/attachments/$mediaId';

  // Stock
  static const stockLevels = '$_v1/stock-levels';
  static const stockIssue = '$_v1/stock-movements/issue';
  static const stockAdjust = '$_v1/stock-movements/adjust';
  static const stockTransfer = '$_v1/stock-movements/transfer';

  // Purchases
  static const purchaseOrders = '$_v1/purchase-orders';
  static String purchaseOrder(String id) => '$_v1/purchase-orders/$id';
  static String purchaseOrderReceipts(String id) =>
      '$_v1/purchase-orders/$id/receipts';

  // Audit
  static const auditEvents = '$_v1/audit-events';

  // Prosthetic
  static const prostheticCases = '$_v1/prosthetic-cases';
  static String prostheticCase(String id) => '$_v1/prosthetic-cases/$id';
  static String prostheticCaseStatus(String id) =>
      '$_v1/prosthetic-cases/$id/status';
  static String prostheticCaseAttachments(String id) =>
      '$_v1/prosthetic-cases/$id/attachments';
  static String prostheticCasePayments(String id) =>
      '$_v1/prosthetic-cases/$id/payments';
  static const prostheticWaitingPlacement =
      '$_v1/prosthetic-cases/waiting-placement';
  static const prostheticDashboard = '$_v1/prosthetic-dashboard';
  static const laboratories = '$_v1/laboratories';
}
