import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Alerts
import '../../features/alerts/presentation/screens/alert_list_screen.dart';
// Auth
import '../../features/auth/presentation/screens/camera_permission_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
// Batches
// Catalog
import '../../features/catalog/presentation/screens/product_list_screen.dart';
// Compliance
import '../../features/compliance/presentation/screens/non_conformities_screen.dart';
// Cycles
import '../../features/cycles/presentation/screens/cycle_attachments_screen.dart';
import '../../features/cycles/presentation/screens/cycle_control_tests_screen.dart';
import '../../features/cycles/presentation/screens/cycle_create_screen.dart';
import '../../features/cycles/presentation/screens/cycle_detail_screen.dart';
import '../../features/cycles/presentation/screens/cycle_items_screen.dart';
import '../../features/cycles/presentation/screens/cycle_list_screen.dart';
import '../../features/cycles/presentation/screens/cycle_release_screen.dart';
// Dashboard
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
// Devices
import '../../features/devices/presentation/screens/device_list_screen.dart';
// DLU
import '../../features/dlu/presentation/screens/dlu_rules_screen.dart';
// History
import '../../features/history/presentation/screens/audit_list_screen.dart';
// Identity
import '../../features/identity/presentation/screens/team_detail_screen.dart';
import '../../features/identity/presentation/screens/team_list_screen.dart';
// Labels
import '../../features/labels/presentation/screens/label_blocked_screen.dart';
import '../../features/labels/presentation/screens/label_detail_screen.dart';
import '../../features/labels/presentation/screens/label_usage_form_screen.dart';
// Locations
// Patients
import '../../features/patients/presentation/screens/patient_search_screen.dart';
// Purchases
import '../../features/purchases/presentation/screens/goods_receipt_screen.dart';
import '../../features/purchases/presentation/screens/purchase_order_detail_screen.dart';
import '../../features/purchases/presentation/screens/purchase_order_list_screen.dart';
// Reporting
import '../../features/reporting/presentation/screens/data_export_request_screen.dart';
// Scanner
import '../../features/scanner/presentation/screens/scanner_screen.dart';
// Settings
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
// Shell
import '../../features/shell/presentation/screens/shell_screen.dart';
// Sites
import '../../features/sites/presentation/screens/site_list_screen.dart';
// Stock
import '../../features/stock/presentation/screens/stock_adjust_screen.dart';
import '../../features/stock/presentation/screens/stock_issue_screen.dart';
import '../../features/stock/presentation/screens/stock_level_list_screen.dart';
import '../../features/stock/presentation/screens/stock_transfer_screen.dart';
// Suppliers
import '../../features/suppliers/presentation/screens/supplier_list_screen.dart';
// Sync
import '../../features/sync/presentation/screens/sync_queue_screen.dart';
import '../../features/devices/presentation/screens/device_detail_screen.dart';
import 'route_names.dart';
import 'routes.dart';

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, c) =>
          FadeTransition(opacity: animation, child: c),
    );

class AppRouter {
  final bool Function() isAuthenticated;
  final Future<bool> Function() hasStoredToken;

  AppRouter({
    required this.isAuthenticated,
    required this.hasStoredToken,
  });

  late final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) async {
      final loc = state.matchedLocation;
      final isPublic = loc == Routes.splash ||
          loc == Routes.login ||
          loc == Routes.register ||
          loc == Routes.cameraPermission;
      if (isPublic) return null;
      if (isAuthenticated()) return null;
      if (await hasStoredToken()) return null;
      return Routes.login;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        name: RouteNames.splash,
        pageBuilder: (_, s) => _fade(s, const SplashScreen()),
      ),
      GoRoute(
        path: Routes.login,
        name: RouteNames.login,
        pageBuilder: (_, s) => _fade(s, const LoginScreen()),
      ),
      GoRoute(
        path: Routes.register,
        name: RouteNames.register,
        pageBuilder: (_, s) => _fade(s, const RegisterScreen()),
      ),
      GoRoute(
        path: Routes.cameraPermission,
        name: RouteNames.cameraPermission,
        pageBuilder: (_, s) => _fade(s, const CameraPermissionScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            name: RouteNames.dashboard,
            pageBuilder: (_, s) => _fade(s, const DashboardScreen()),
          ),
          GoRoute(
            path: Routes.scanner,
            name: RouteNames.scanner,
            pageBuilder: (_, s) => _fade(s, const ScannerScreen()),
          ),
          GoRoute(
            path: Routes.cycles,
            name: RouteNames.cycles,
            pageBuilder: (_, s) => _fade(s, const CycleListScreen()),
          ),
          GoRoute(
            path: Routes.alerts,
            name: RouteNames.alerts,
            pageBuilder: (_, s) => _fade(s, const AlertListScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            name: RouteNames.settings,
            pageBuilder: (_, s) => _fade(s, const SettingsScreen()),
          ),
          GoRoute(
            path: Routes.stock,
            name: RouteNames.stock,
            pageBuilder: (_, s) => _fade(s, const StockLevelListScreen()),
          ),
          GoRoute(
            path: Routes.stockIssue,
            name: RouteNames.stockIssue,
            pageBuilder: (_, s) => _fade(s, const StockIssueScreen()),
          ),
          GoRoute(
            path: Routes.stockAdjust,
            name: RouteNames.stockAdjust,
            pageBuilder: (_, s) => _fade(s, const StockAdjustScreen()),
          ),
          GoRoute(
            path: Routes.stockTransfer,
            name: RouteNames.stockTransfer,
            pageBuilder: (_, s) => _fade(s, const StockTransferScreen()),
          ),
          GoRoute(
            path: Routes.patients,
            name: RouteNames.patients,
            pageBuilder: (_, s) => _fade(s, const PatientSearchScreen()),
          ),
          GoRoute(
            path: Routes.cyclesCreate,
            name: RouteNames.cyclesCreate,
            pageBuilder: (_, s) => _fade(s, const CycleCreateScreen()),
          ),
          GoRoute(
            path: '/app/cycles/:id',
            name: RouteNames.cyclesDetail,
            pageBuilder: (_, s) => _fade(
              s,
              CycleDetailScreen(cycleId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/app/cycles/:id/items',
            pageBuilder: (_, s) => _fade(
              s,
              CycleItemsScreen(cycleId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/app/cycles/:id/control-tests',
            pageBuilder: (_, s) => _fade(
              s,
              CycleControlTestsScreen(cycleId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/app/cycles/:id/attachments',
            pageBuilder: (_, s) => _fade(
              s,
              CycleAttachmentsScreen(cycleId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/app/cycles/:id/release',
            pageBuilder: (_, s) => _fade(
              s,
              CycleReleaseScreen(cycleId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/app/labels/:code',
            name: RouteNames.labelsDetail,
            pageBuilder: (_, s) => _fade(
              s,
              LabelDetailScreen(code: s.pathParameters['code']!),
            ),
          ),
          GoRoute(
            path: '/app/labels/:code/blocked',
            name: RouteNames.labelsBlocked,
            pageBuilder: (_, s) => _fade(
              s,
              LabelBlockedScreen(code: s.pathParameters['code']!),
            ),
          ),
          GoRoute(
            path: '/app/labels/:labelId/usage',
            name: RouteNames.labelsUsage,
            pageBuilder: (_, s) => _fade(
              s,
              LabelUsageFormScreen(labelId: s.pathParameters['labelId']!),
            ),
          ),
          GoRoute(
            path: Routes.team,
            pageBuilder: (_, s) => _fade(s, const TeamListScreen()),
          ),
          GoRoute(
            path: '/app/team/:id',
            pageBuilder: (_, s) => _fade(
              s,
              TeamDetailScreen(memberId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: Routes.sites,
            pageBuilder: (_, s) => _fade(s, const SiteListScreen()),
          ),
          GoRoute(
            path: Routes.nonConformities,
            pageBuilder: (_, s) => _fade(s, const NonConformitiesScreen()),
          ),
          GoRoute(
            path: Routes.dataExports,
            pageBuilder: (_, s) => _fade(s, const DataExportRequestScreen()),
          ),
          GoRoute(
            path: Routes.audit,
            name: RouteNames.audit,
            pageBuilder: (_, s) => _fade(s, const AuditListScreen()),
          ),
          GoRoute(
            path: Routes.sync,
            name: RouteNames.sync,
            pageBuilder: (_, s) => _fade(s, const SyncQueueScreen()),
          ),
          GoRoute(
            path: Routes.about,
            name: RouteNames.about,
            pageBuilder: (_, s) => _fade(s, const AboutScreen()),
          ),
          GoRoute(
            path: Routes.devices,
            pageBuilder: (_, s) => _fade(s, const DeviceListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _fade(
                  s,
                  DeviceDetailScreen(deviceId: s.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.products,
            pageBuilder: (_, s) => _fade(s, const ProductListScreen()),
          ),
          GoRoute(
            path: Routes.suppliers,
            pageBuilder: (_, s) => _fade(s, const SupplierListScreen()),
          ),
          GoRoute(
            path: Routes.purchases,
            pageBuilder: (_, s) => _fade(s, const PurchaseOrderListScreen()),
          ),
          GoRoute(
            path: '/app/purchases/:id',
            pageBuilder: (_, s) => _fade(
              s,
              PurchaseOrderDetailScreen(poId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/app/purchases/:id/receive',
            pageBuilder: (_, s) => _fade(
              s,
              GoodsReceiptScreen(poId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: Routes.dluRules,
            pageBuilder: (_, s) => _fade(s, const DluRulesScreen()),
          ),
          GoRoute(
            path: Routes.devices,
            pageBuilder: (_, s) => _fade(s, const DeviceListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _fade(
                  s,
                  DeviceDetailScreen(deviceId: s.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
