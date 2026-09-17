class DashboardKpi {
  final String id;
  final String label;
  final int value;
  final String route;
  const DashboardKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.route,
  });
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
  const DashboardRecentProcedure({
    required this.id,
    required this.label,
    required this.patientReference,
    required this.usedAt,
  });
}

class DashboardData {
  final String greeting;
  final String userName;
  final List<DashboardKpi> kpis;
  final List<DashboardAttentionItem> attention;
  final List<DashboardTodayCycle> todayCycles;
  final List<DashboardRecentProcedure> recentProcedures;

  const DashboardData({
    required this.greeting,
    required this.userName,
    required this.kpis,
    required this.attention,
    required this.todayCycles,
    required this.recentProcedures,
  });

  DashboardData copyWith({String? userName}) => DashboardData(
        greeting: greeting,
        userName: userName ?? this.userName,
        kpis: kpis,
        attention: attention,
        todayCycles: todayCycles,
        recentProcedures: recentProcedures,
      );
}
