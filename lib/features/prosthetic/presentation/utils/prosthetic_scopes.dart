/// The seven dashboard widgets of brief §5. Each one IS a server `scope`: the
/// card's number and the list it opens are produced by the same server query,
/// so they cannot disagree (no dead KPI).
abstract final class ProstheticScope {
  static const active = 'active';
  static const atLaboratory = 'at_laboratory';
  static const returnedToPractice = 'returned_to_practice';
  static const waitingForPlacement = 'waiting_for_placement';
  static const placementsToday = 'placements_today';
  static const placementsThisWeek = 'placements_this_week';
  static const paymentsDue = 'payments_due';

  static const all = [
    active,
    atLaboratory,
    returnedToPractice,
    waitingForPlacement,
    placementsToday,
    placementsThisWeek,
    paymentsDue,
  ];

  /// Short French label, used for the list's filter chip.
  static String label(String scope) => switch (scope) {
        active => 'Travaux actifs',
        atLaboratory => 'Chez le laboratoire',
        returnedToPractice => 'Revenus au cabinet',
        waitingForPlacement => 'En attente de pose',
        placementsToday => 'Poses aujourd\'hui',
        placementsThisWeek => 'Poses cette semaine',
        paymentsDue => 'Paiements à vérifier',
        _ => scope,
      };
}
