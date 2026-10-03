import '../../data/repositories/prosthetic_repository.dart';
import 'prosthetic_scopes.dart';

/// How much work a laboratory currently holds for the practice, counted by the
/// server over the whole set (never over a loaded page).
class LaboratoryStats {
  /// Cases sent to the laboratory and not yet back.
  final int atLaboratory;

  /// Cases back from the laboratory and not yet placed.
  final int waitingForPlacement;

  /// Of those, by how long they have waited: 0-7, 8-14, 15+ days.
  final int fresh;
  final int medium;
  final int urgent;

  /// Every case ever given to this laboratory.
  final int total;

  const LaboratoryStats({
    required this.atLaboratory,
    required this.waitingForPlacement,
    required this.fresh,
    required this.medium,
    required this.urgent,
    required this.total,
  });

  bool get hasUrgent => urgent > 0;
}

/// Three server-side counts for one laboratory. A failure throws: the caller
/// shows "unavailable", never zero.
Future<LaboratoryStats> loadLaboratoryStats(
  ProstheticRepository repo,
  String laboratoryId,
) async {
  final results = await Future.wait([
    repo.summary(
      laboratoryId: laboratoryId,
      scope: ProstheticScope.atLaboratory,
    ),
    repo.summary(
      laboratoryId: laboratoryId,
      scope: ProstheticScope.waitingForPlacement,
    ),
    repo.summary(laboratoryId: laboratoryId),
  ]);
  final waiting = results[1];
  return LaboratoryStats(
    atLaboratory: results[0].total,
    waitingForPlacement: waiting.total,
    fresh: waiting.fresh,
    medium: waiting.medium,
    urgent: waiting.urgent,
    total: results[2].total,
  );
}
