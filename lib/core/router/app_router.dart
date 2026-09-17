import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/screens/alert_list_screen.dart';
import '../../features/auth/presentation/screens/camera_permission_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/compliance/presentation/screens/non_conformities_screen.dart';
import '../../features/cycles/presentation/screens/cycle_attachments_screen.dart';
import '../../features/cycles/presentation/screens/cycle_control_tests_screen.dart';
import '../../features/cycles/presentation/screens/cycle_create_screen.dart';
import '../../features/cycles/presentation/screens/cycle_detail_screen.dart';
import '../../features/cycles/presentation/screens/cycle_items_screen.dart';
import '../../features/cycles/presentation/screens/cycle_list_screen.dart';
import '../../features/cycles/presentation/screens/cycle_release_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/history/presentation/screens/audit_list_screen.dart';
import '../../features/identity/presentation/screens/team_detail_screen.dart';
import '../../features/identity/presentation/screens/team_list_screen.dart';
import '../../features/labels/presentation/screens/label_blocked_screen.dart';
import '../../features/labels/presentation/screens/label_detail_screen.dart';
import '../../features/labels/presentation/screens/label_usage_form_screen.dart';
import '../../features/patients/presentation/screens/patient_search_screen.dart';
import '../../features/reporting/presentation/screens/data_export_request_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/screens/shell_screen.dart';
import '../../features/stock/presentation/screens/stock_adjust_screen.dart';
import '../../features/stock/presentation/screens/stock_issue_screen.dart';
import '../../features/stock/presentation/screens/stock_level_list_screen.dart';
import '../../features/stock/presentation/screens/stock_transfer_screen.dart';
import '../../features/sync/presentation/screens/sync_queue_screen.dart';
import '../../features/tenancy/presentation/screens/site_list_screen.dart';

import 'route_names.dart';
import 'routes.dart';

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
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        name: RouteNames.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.cameraPermission,
        name: RouteNames.cameraPermission,
        builder: (_, __) => const CameraPermissionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            name: RouteNames.dashboard,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: Routes.scanner,
            name: RouteNames.scanner,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ScannerScreen()),
          ),
          GoRoute(
            path: Routes.cycles,
            name: RouteNames.cycles,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: CycleListScreen()),
          ),
          GoRoute(
            path: Routes.alerts,
            name: RouteNames.alerts,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AlertListScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            name: RouteNames.settings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: Routes.stock,
            name: RouteNames.stock,
            builder: (_, __) => const StockLevelListScreen(),
          ),
          GoRoute(
            path: Routes.stockIssue,
            name: RouteNames.stockIssue,
            builder: (_, __) => const StockIssueScreen(),
          ),
          GoRoute(
            path: Routes.stockAdjust,
            name: RouteNames.stockAdjust,
            builder: (_, __) => const StockAdjustScreen(),
          ),
          GoRoute(
            path: Routes.stockTransfer,
            name: RouteNames.stockTransfer,
            builder: (_, __) => const StockTransferScreen(),
          ),
          GoRoute(
            path: Routes.patients,
            name: RouteNames.patients,
            builder: (_, __) => const PatientSearchScreen(),
          ),
          GoRoute(
            path: Routes.cyclesCreate,
            name: RouteNames.cyclesCreate,
            builder: (_, __) => const CycleCreateScreen(),
          ),
          GoRoute(
            path: '/app/cycles/:id',
            name: RouteNames.cyclesDetail,
            builder: (_, state) =>
                CycleDetailScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/items',
            name: RouteNames.cyclesItems,
            builder: (_, state) =>
                CycleItemsScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/control-tests',
            name: RouteNames.cyclesControlTests,
            builder: (_, state) => CycleControlTestsScreen(
                cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/attachments',
            name: RouteNames.cyclesAttachments,
            builder: (_, state) => CycleAttachmentsScreen(
                cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/release',
            name: RouteNames.cyclesRelease,
            builder: (_, state) =>
                CycleReleaseScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/labels/:code',
            name: RouteNames.labelsDetail,
            builder: (_, state) =>
                LabelDetailScreen(code: state.pathParameters['code']!),
          ),
          GoRoute(
            path: '/app/labels/:code/blocked',
            name: RouteNames.labelsBlocked,
            builder: (_, state) =>
                LabelBlockedScreen(code: state.pathParameters['code']!),
          ),
          GoRoute(
            path: '/app/labels/:labelId/usage',
            name: RouteNames.labelsUsage,
            builder: (_, state) => LabelUsageFormScreen(
                labelId: state.pathParameters['labelId']!),
          ),
          GoRoute(
            path: Routes.team,
            builder: (_, __) => const TeamListScreen(),
          ),
          GoRoute(
            path: '/app/team/:id',
            builder: (_, state) =>
                TeamDetailScreen(memberId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: Routes.sites,
            builder: (_, __) => const SiteListScreen(),
          ),
          GoRoute(
            path: Routes.nonConformities,
            builder: (_, __) => const NonConformitiesScreen(),
          ),
          GoRoute(
            path: Routes.dataExports,
            builder: (_, __) => const DataExportRequestScreen(),
          ),
          GoRoute(
            path: Routes.audit,
            name: RouteNames.audit,
            builder: (_, __) => const AuditListScreen(),
          ),
          GoRoute(
            path: Routes.sync,
            name: RouteNames.sync,
            builder: (_, __) => const SyncQueueScreen(),
          ),
          GoRoute(
            path: Routes.about,
            name: RouteNames.about,
            builder: (_, __) => const AboutScreen(),
          ),
        ],
      ),
    ],
  );
}
