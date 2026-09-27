class ProstheticDashboardData {
  final int activeCases;
  final int atLaboratory;
  final int returnedToPractice;
  final int waitingForPlacement;
  final int placementsToday;
  final int placementsThisWeek;
  final int depositsOrBalancesDue;

  const ProstheticDashboardData({
    required this.activeCases,
    required this.atLaboratory,
    required this.returnedToPractice,
    required this.waitingForPlacement,
    required this.placementsToday,
    required this.placementsThisWeek,
    required this.depositsOrBalancesDue,
  });

  factory ProstheticDashboardData.fromJson(Map<String, dynamic> json) =>
      ProstheticDashboardData(
        activeCases: (json['active_cases'] as num?)?.toInt() ?? 0,
        atLaboratory: (json['at_laboratory'] as num?)?.toInt() ?? 0,
        returnedToPractice:
            (json['returned_to_practice'] as num?)?.toInt() ?? 0,
        waitingForPlacement:
            (json['waiting_for_placement'] as num?)?.toInt() ?? 0,
        placementsToday: (json['placements_today'] as num?)?.toInt() ?? 0,
        placementsThisWeek:
            (json['placements_this_week'] as num?)?.toInt() ?? 0,
        depositsOrBalancesDue:
            (json['deposits_or_balances_due'] as num?)?.toInt() ?? 0,
      );
}
