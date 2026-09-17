abstract final class ApiEndpoints {
  static const _v1 = '/v1';

  // Auth
  static const login = '$_v1/auth/login';
  static const register = '$_v1/tenants';
  static const logout = '$_v1/auth/logout';
  static const logoutEverywhere = '$_v1/auth/tokens';
  static const me = '$_v1/me';

  // Alerts
  static const alerts = '$_v1/alerts';
  static String alertResolve(String id) => '$_v1/alerts/$id/resolve';

  // Labels
  static String labelByCode(String code) => '$_v1/labels/$code';
  static String labelUsage(String labelId) => '$_v1/labels/$labelId/usage';

  // Patients
  static const patients = '$_v1/patients';
  static String patient(String id) => '$_v1/patients/$id';

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

  // Audit
  static const auditEvents = '$_v1/audit-events';

  // Compliance
  static const nonConformities = '$_v1/non-conformities';
  static String nonConformity(String id) => '$_v1/non-conformities/$id';
  static String nonConformityResolve(String id) =>
      '$_v1/non-conformities/$id/resolve';

  // Sites
  static const sites = '$_v1/sites';

  // Team
  static const invitations = '$_v1/invitations';
  static String invitation(String id) => '$_v1/invitations/$id';
  static String member(String tenantUserId) => '$_v1/members/$tenantUserId';
}
