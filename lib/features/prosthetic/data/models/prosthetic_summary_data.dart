/// Server-side total for a filter/scope set, plus the 0-7 / 8-14 / 15+ day
/// aging buckets of the waiting-for-placement set. Counted by the server over
/// the WHOLE result, never over the page the app has loaded.
class ProstheticSummaryData {
  final int total;
  final int fresh;
  final int medium;
  final int urgent;

  const ProstheticSummaryData({
    required this.total,
    this.fresh = 0,
    this.medium = 0,
    this.urgent = 0,
  });

  factory ProstheticSummaryData.fromJson(Map<String, dynamic> json) {
    final aging = json['aging'];
    final buckets = aging is Map ? aging.cast<String, dynamic>() : const {};
    return ProstheticSummaryData(
      total: (json['total'] as num?)?.toInt() ?? 0,
      fresh: (buckets['fresh'] as num?)?.toInt() ?? 0,
      medium: (buckets['medium'] as num?)?.toInt() ?? 0,
      urgent: (buckets['urgent'] as num?)?.toInt() ?? 0,
    );
  }
}
