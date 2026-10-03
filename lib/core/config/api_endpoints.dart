abstract final class ApiEndpoints {
  static const _v1 = '/v1';

  // Auth
  static const login = '$_v1/auth/login';
  static const register = '$_v1/tenants';
  static const logout = '$_v1/auth/logout';
  static const logoutEverywhere = '$_v1/auth/tokens';
  static const forgotPassword = '$_v1/auth/forgot-password';
  static const resetPassword = '$_v1/auth/reset-password';
  static const me = '$_v1/me';

  // Alerts
  static const alerts = '$_v1/alerts';
  static const pushTokens = '$_v1/push-tokens';
  static String alertResolve(String id) => '$_v1/alerts/$id/resolve';

  // Labels
  static String labelByCode(String code) => '$_v1/labels/$code';
  static String labelUsage(String labelId) => '$_v1/labels/$labelId/usage';
  static String labelUsageDossier(String labelId) =>
      '$_v1/labels/$labelId/usage/dossier';

  // Patients
  static const patients = '$_v1/patients';
  static String patient(String id) => '$_v1/patients/$id';

  // Products
  static const products = '$_v1/products';
  static String product(String id) => '$_v1/products/$id';
  static const productCategories = '$_v1/product-categories';

  // Suppliers
  static const suppliers = '$_v1/suppliers';
  static String supplier(String id) => '$_v1/suppliers/$id';
  static String supplierProducts(String id) => '$_v1/suppliers/$id/products';

  // Purchase orders
  static const purchaseOrders = '$_v1/purchase-orders';
  static String purchaseOrder(String id) => '$_v1/purchase-orders/$id';
  static String purchaseOrderOrder(String id) =>
      '$_v1/purchase-orders/$id/order';
  static String purchaseOrderCancel(String id) =>
      '$_v1/purchase-orders/$id/cancel';
  static String purchaseOrderReceipts(String id) =>
      '$_v1/purchase-orders/$id/receipts';
  static String goodsReceipt(String id) => '$_v1/goods-receipts/$id';
  static String goodsReceiptAttachments(String id) =>
      '$_v1/goods-receipts/$id/attachments';
  // Proof photo of a delivery; the bytes travel in the JSON body (same
  // contract as the cycle attachments).
  static String goodsReceiptAttachmentsBase64(String id) =>
      '$_v1/goods-receipts/$id/attachments-base64';

  // Lookups for pickers (complete, paginated, independent of stock rows)
  static const locations = '$_v1/locations';
  static const batches = '$_v1/batches';
  static const practitioners = '$_v1/practitioners';

  // Sites
  static const sites = '$_v1/sites';
  static String site(String id) => '$_v1/sites/$id';

  // Devices
  static const devices = '$_v1/devices';
  static String device(String id) => '$_v1/devices/$id';
  static String devicePrograms(String id) => '$_v1/devices/$id/programs';
  static String deviceProgram(String id, String programId) =>
      '$_v1/devices/$id/programs/$programId';
  static String deviceMaintenanceRecords(String id) =>
      '$_v1/devices/$id/maintenance-records';

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
  // Same effect as the multipart route, but the bytes travel inside the JSON
  // body: the multipart route answers 500 behind FrankenPHP/Octane workers.
  static String cycleAttachmentsBase64(String id) =>
      '$_v1/cycles/$id/attachments-base64';
  static String cycleAttachment(String id, String attachmentId) =>
      '$_v1/cycles/$id/attachments/$attachmentId';
  static String cycleLabels(String id) => '$_v1/cycles/$id/labels';

  // Stock
  static const stockLevels = '$_v1/stock-levels';
  static const stockIssue = '$_v1/stock-movements/issue';
  static const stockAdjust = '$_v1/stock-movements/adjust';
  static const stockTransfer = '$_v1/stock-movements/transfer';
  // Resolves a scanned/typed product barcode, product reference or batch number.
  static const codeLookup = '$_v1/lookups/code';

  // Inventory counts ("inventaire")
  static const inventoryCounts = '$_v1/inventory-counts';
  static String inventoryCount(String id) => '$_v1/inventory-counts/$id';
  static String inventoryCountLine(String id, String batchId) =>
      '$_v1/inventory-counts/$id/lines/$batchId';
  static String inventoryCountClose(String id) =>
      '$_v1/inventory-counts/$id/close';
  static String inventoryCountCancel(String id) =>
      '$_v1/inventory-counts/$id/cancel';

  // Audit
  static const auditEvents = '$_v1/audit-events';

  // Compliance
  static const nonConformities = '$_v1/non-conformities';
  static String nonConformity(String id) => '$_v1/non-conformities/$id';
  static String nonConformityResolve(String id) =>
      '$_v1/non-conformities/$id/resolve';

  // DLU
  static const dluRules = '$_v1/dlu-rules';
  static String dluRule(String id) => '$_v1/dlu-rules/$id';

  // Evidence
  static const evidenceSearch = '$_v1/evidence-search';
  static const evidenceExport = '$_v1/evidence-search/export';

  // Team
  static const invitations = '$_v1/invitations';
  static String invitation(String id) => '$_v1/invitations/$id';
  static String invitationResend(String id) => '$_v1/invitations/$id/resend';
  static const members = '$_v1/members';
  static String member(String tenantUserId) => '$_v1/members/$tenantUserId';

  // Reporting
  static const dataExports = '$_v1/data-export-requests';
  static String dataExport(String id) => '$_v1/data-export-requests/$id';
  static String dataExportDownload(String id) =>
      '$_v1/data-export-requests/$id/download';

  // Prosthetic
  static const prostheticDashboard = '$_v1/prosthetic-dashboard';
  static const prostheticWaitingPlacement =
      '$_v1/prosthetic-cases/waiting-placement';
  static const prostheticCases = '$_v1/prosthetic-cases';
  static const prostheticCasesSummary = '$_v1/prosthetic-cases/summary';
  static String prostheticCase(String id) => '$_v1/prosthetic-cases/$id';
  static String prostheticCaseStatus(String id) =>
      '$_v1/prosthetic-cases/$id/status';
  static String prostheticCaseStatusHistory(String id) =>
      '$_v1/prosthetic-cases/$id/status-history';
  static String prostheticCaseAttachments(String id) =>
      '$_v1/prosthetic-cases/$id/attachments';
  static String prostheticCaseAttachment(String id, String attachmentId) =>
      '$_v1/prosthetic-cases/$id/attachments/$attachmentId';
  static const laboratories = '$_v1/laboratories';
  static String laboratory(String id) => '$_v1/laboratories/$id';
}
