import '../../features/stock/data/repositories/stock_repository.dart';
import '../crash/crash_reporter.dart';
import '../storage/session_store.dart';

/// Leaves a Sentry breadcrumb when a tenant starts the app with no batches and
/// no locations at all ("clinic not set up yet"), so that state is visible from
/// day one instead of only showing up as a support ticket. Every stock screen
/// already shows its own empty-state card for it.
///
/// Runs once at startup, fire-and-forget and non-fatal; never blocks bootstrap
/// and never shows UI itself.
Future<void> checkStockSeedStatus({
  required SessionStore session,
  required StockRepository stockRepository,
  required CrashReporter crashReporter,
}) async {
  if (!session.hasSession) return;
  try {
    final opts = await stockRepository.listOptions();
    if (opts.batches.isEmpty && opts.locations.isEmpty) {
      crashReporter.breadcrumb(
        'stock seed check: tenant has no batches or locations at startup',
        data: {'tenantId': session.tenant?['id']},
      );
    }
  } catch (_) {
    // Best-effort diagnostic only — never fail bootstrap over this.
  }
}
