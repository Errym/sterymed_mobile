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

  factory DashboardKpi.fromJson(Map<String, dynamic> json) => DashboardKpi(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        value: (json['value'] as num?)?.toInt() ?? 0,
        route: json['route']?.toString() ?? '',
      );
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

  factory DashboardAttentionItem.fromJson(Map<String, dynamic> json) =>
      DashboardAttentionItem(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'info',
        route: json['route']?.toString() ?? '',
      );
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

  factory DashboardTodayCycle.fromJson(Map<String, dynamic> json) =>
      DashboardTodayCycle(
        id: json['id']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        deviceName: json['device_name']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );
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

  factory DashboardRecentProcedure.fromJson(Map<String, dynamic> json) =>
      DashboardRecentProcedure(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        patientReference: json['patient_reference']?.toString() ?? '',
        usedAt: json['used_at']?.toString() ?? '',
      );
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

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        greeting: json['greeting']?.toString() ?? 'Bonjour',
        userName: json['user_name']?.toString() ?? '',
        kpis: (json['kpis'] as List?)
                ?.map((e) =>
                    DashboardKpi.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        attention: (json['attention'] as List?)
                ?.map((e) => DashboardAttentionItem.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        todayCycles: (json['today_cycles'] as List?)
                ?.map((e) => DashboardTodayCycle.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        recentProcedures: (json['recent_procedures'] as List?)
                ?.map((e) => DashboardRecentProcedure.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}
