import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/screens/alert_list_screen.dart';
import '../../features/auth/presentation/screens/camera_permission_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/cycles/presentation/screens/cycle_attachments_screen.dart';
import '../../features/cycles/presentation/screens/cycle_control_tests_screen.dart';
import '../../features/cycles/presentation/screens/cycle_create_screen.dart';
import '../../features/cycles/presentation/screens/cycle_detail_screen.dart';
import '../../features/cycles/presentation/screens/cycle_items_screen.dart';
import '../../features/cycles/presentation/screens/cycle_list_screen.dart';
import '../../features/cycles/presentation/screens/cycle_release_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/labels/presentation/screens/label_blocked_screen.dart';
import '../../features/labels/presentation/screens/label_detail_screen.dart';
import '../../features/labels/presentation/screens/label_usage_form_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/patients/presentation/screens/patient_search_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/screens/shell_screen.dart';
import 'route_names.dart';
import 'routes.dart';

class AppRouter {
  final bool Function() isAuthenticated;

  AppRouter({required this.isAuthenticated});

  late final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isPublic = loc == Routes.splash ||
          loc == Routes.onboarding ||
          loc == Routes.login ||
          loc == Routes.register ||
          loc == Routes.cameraPermission;
      final authed = isAuthenticated();

      if (!authed && !isPublic) return Routes.login;
      if (authed && (loc == Routes.login || loc == Routes.register)) {
        return Routes.dashboard;
      }
      return null;
    },
    routes: [
      // ═════════════════════════════════════════════════════════════
      // PUBLIC ROUTES
      // ═════════════════════════════════════════════════════════════
      GoRoute(
        path: Routes.splash,
        name: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        name: RouteNames.onboarding,
        builder: (_, __) => const OnboardingScreen(),
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

      // ═════════════════════════════════════════════════════════════
      // AUTHENTICATED SHELL
      // ═════════════════════════════════════════════════════════════
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          // ── Tabs (bottom nav) ─────────────────────────────────
          GoRoute(
            path: Routes.dashboard,
            name: RouteNames.dashboard,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.scanner,
            name: RouteNames.scanner,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ScannerScreen(),
            ),
          ),
          GoRoute(
            path: Routes.cycles,
            name: RouteNames.cycles,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: CycleListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.alerts,
            name: RouteNames.alerts,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AlertListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            name: RouteNames.settings,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),

          // ── Patients ──────────────────────────────────────────
          GoRoute(
            path: Routes.patients,
            name: RouteNames.patients,
            builder: (_, __) => const PatientSearchScreen(),
          ),

          // ── Cycles (nested) ───────────────────────────────────
          GoRoute(
            path: '/app/cycles/create',
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
            builder: (_, state) =>
                CycleItemsScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/control-tests',
            builder: (_, state) =>
                CycleControlTestsScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/attachments',
            builder: (_, state) =>
                CycleAttachmentsScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/release',
            builder: (_, state) =>
                CycleReleaseScreen(cycleId: state.pathParameters['id']!),
          ),

          // ── Labels (nested) ───────────────────────────────────
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
            builder: (_, state) =>
                LabelUsageFormScreen(labelId: state.pathParameters['labelId']!),
          ),
        ],
      ),
    ],
  );
}