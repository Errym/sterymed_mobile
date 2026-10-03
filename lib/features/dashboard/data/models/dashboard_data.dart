class DashboardKpi {
  final String id;
  final String label;

  /// Null means the figure could not be loaded. That is not zero: a zero
  /// says "nothing to do", an unavailable figure says "we do not know".
  final int? value;

  /// True when the server had more rows than the one page we counted, so the
  /// real figure is at least [value] ("50+").
  final bool approximate;
  final String route;
  const DashboardKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.route,
    this.approximate = false,
  });

  bool get isUnavailable => value == null;
}

class DashboardAttentionItem {
  final String id;
  final String label;
  final String severity;
  final String route;
  const DashboardAttentionItem({
    required this.id,
    required this.label,
    required this.severity,
    required this.route,
  });
}

class DashboardTodayCycle {
  final String id;
  final String number;
  final String deviceName;
  final String status;
  const DashboardTodayCycle({
    required this.id,
    required this.number,
    required this.deviceName,
    required this.status,
  });
}

class DashboardRecentProcedure {
  final String id;
  final String label;
  final String patientReference;
  final String usedAt;

  /// Who did it (the audit trail's own snapshot of the person's name).
  final String actor;
  const DashboardRecentProcedure({
    required this.id,
    required this.label,
    required this.patientReference,
    required this.usedAt,
    this.actor = '',
  });
}

/// Stock health read from the real stock levels.
class StockInsight {
  final int rows;

  /// Rows that are neither under their minimum nor expired.
  final int healthy;
  final int low;
  final int expired;
  final int nearExpiry;

  /// True when the server holds more rows than were read: every figure here
  /// is then a lower bound, and the screen must say so instead of presenting
  /// a share of a sample as the whole truth.
  final bool partial;
  const StockInsight({
    required this.rows,
    required this.healthy,
    required this.low,
    required this.expired,
    required this.nearExpiry,
    this.partial = false,
  });

  /// Share of stock rows in good standing, 0-100. Null with no rows at all:
  /// there is nothing to judge, so no made-up 100%.
  int? get healthPercent => rows == 0 ? null : (healthy * 100 / rows).round();

  int get attention => low + expired + nearExpiry;
}

/// Purchase orders that still need a person to act.
class PurchaseInsight {
  /// Ordered or partly received: goods are expected.
  final int toReceive;

  /// Of those, past their expected delivery date.
  final int late;
  const PurchaseInsight({required this.toReceive, required this.late});
}

/// The counters of `GET /v1/prosthetic-dashboard`, as the server computes them.
class ProstheticInsight {
  final int active;
  final int atLaboratory;
  final int returned;
  final int waitingForPlacement;
  final int placementsToday;
  final int placementsThisWeek;
  final int paymentsDue;
  const ProstheticInsight({
    required this.active,
    required this.atLaboratory,
    required this.returned,
    required this.waitingForPlacement,
    required this.placementsToday,
    required this.placementsThisWeek,
    required this.paymentsDue,
  });
}

/// The role-dependent part of the home screen. A section is null when it
/// could not be read; [unavailable] says which, so the screen can say "could
/// not check" instead of staying silent or showing a zero.
class DashboardInsights {
  final StockInsight? stock;
  final PurchaseInsight? purchases;
  final ProstheticInsight? prosthetic;

  /// Cycles whose controls are entered and that wait for a release decision.
  final int? awaitingRelease;
  final Set<String> unavailable;

  const DashboardInsights({
    this.stock,
    this.purchases,
    this.prosthetic,
    this.awaitingRelease,
    this.unavailable = const {},
  });
}

class DashboardData {
  final String greeting;
  final String userName;
  final List<DashboardKpi> kpis;
  final List<DashboardAttentionItem> attention;
  final List<DashboardTodayCycle> todayCycles;
  final List<DashboardRecentProcedure> recentProcedures;

  /// Sections whose request failed: any of `cycles`, `alerts`, `audit`.
  final Set<String> unavailable;

  /// When these figures were read from the server.
  final DateTime? fetchedAt;

  /// True when a refresh failed and these are the figures of an earlier read.
  final bool stale;

  /// Stock, purchasing, prosthetic and release figures for the roles that may
  /// see them.
  final DashboardInsights insights;

  const DashboardData({
    required this.greeting,
    required this.userName,
    required this.kpis,
    required this.attention,
    required this.todayCycles,
    required this.recentProcedures,
    this.unavailable = const {},
    this.fetchedAt,
    this.stale = false,
    this.insights = const DashboardInsights(),
  });

  bool get hasUnavailable =>
      unavailable.isNotEmpty || insights.unavailable.isNotEmpty;

  DashboardData copyWith({String? userName, bool? stale}) => DashboardData(
        greeting: greeting,
        userName: userName ?? this.userName,
        kpis: kpis,
        attention: attention,
        todayCycles: todayCycles,
        recentProcedures: recentProcedures,
        unavailable: unavailable,
        fetchedAt: fetchedAt,
        stale: stale ?? this.stale,
        insights: insights,
      );
}
