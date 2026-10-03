/// The server writes alert texts in English (they are stored once and shared
/// with the web). A French clinic must read French, so the four texts the
/// server produces are translated here, from their fixed shape. Anything
/// that does not match is shown exactly as received: never guessed at,
/// never dropped.
String localizeAlertMessage(String type, String message) {
  String date(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }

  switch (type) {
    case 'low_stock':
      final m = RegExp(r'^Stock for "(.+)" is below threshold \((\d+)/(\d+)\)\.$')
          .firstMatch(message);
      if (m != null) {
        return 'Stock de « ${m[1]} » sous le seuil (${m[2]} sur ${m[3]}).';
      }
    case 'expired':
      final m = RegExp(r'^Batch "(.+)" expired on (\d{4}-\d{2}-\d{2})\.$')
          .firstMatch(message);
      if (m != null) return 'Lot « ${m[1]} » périmé depuis le ${date(m[2]!)}.';
    case 'near_expiry':
      final m = RegExp(r'^Batch "(.+)" expires on (\d{4}-\d{2}-\d{2})\.$')
          .firstMatch(message);
      if (m != null) return 'Lot « ${m[1]} » expire le ${date(m[2]!)}.';
    case 'failed_cycle':
      final m = RegExp(r'^Cycle #(\S+) failed a (\w+) control test\.$')
          .firstMatch(message);
      if (m != null) {
        const tests = {
          'vacuum': 'test de vide',
          'bowie_dick': 'test de Bowie-Dick',
          'helix': 'test Helix',
          'biological': 'test biologique',
        };
        final test = tests[m[2]] ?? 'test de contrôle « ${m[2]} »';
        return 'Cycle n°${m[1]} : $test échoué.';
      }
  }
  return message;
}
