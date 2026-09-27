import '../../features/stock/data/repositories/stock_repository.dart';
import '../crash/crash_reporter.dart';
import '../storage/session_store.dart';

/// Task 3.1 mitigation, part (b) — for BUG-002/BUG-003 (no dedicated
/// `GET /locations` or `GET /batches` endpoint on the real backend).
/// Mobile derives stock options from `GET /stock-levels` instead
/// (`StockRemoteDatasource.listOptions()`), which is correct but means a
/// brand-new tenant with zero stock movements ever recorded has zero
/// batches AND zero locations. Every stock action screen already handles
/// that case with its own empty-state card (part (a) — see
/// `_NoStockCard` in stock_issue_screen.dart / stock_adjust_screen.dart /
/// stock_transfer_screen.dart, all pre-existing) — but nothing previously
/// surfaced that a tenant is in this state before a user actually opens
/// one of those screens.
///
/// This runs once at startup, fire-and-forget and non-fatal: it leaves a
/// breadcrumb so "tenant has never received any stock" is visible in
/// Sentry from day one instead of only showing up as a support ticket.
/// It never blocks bootstrap and never shows UI itself.
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
