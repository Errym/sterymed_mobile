import 'package:dio/dio.dart';

import '../errors/api_exception.dart';
import '../errors/error_mapper.dart';

/// Turn an exception object into a clean, user-facing French string.
/// The API already returns French messages — we strip the boilerplate
/// `ApiException(code: ..., status: ...)` wrapper and keep just the message.
abstract final class ErrorMessage {
  /// The server\'s business rules answer in English with a stable code. These
  /// are the ones a user can actually hit, worded for them in French; the app
  /// branches on the code, never on the server\'s wording.
  static const _frenchByCode = <String, String>{
    'OWNER_ROLE_REQUIRED':
        'Seule la direction peut inviter ou désactiver un membre de la direction.',
    'CANNOT_DISABLE_SELF': 'Vous ne pouvez pas désactiver votre propre accès.',
    'LAST_OWNER':
        'Le dernier membre de la direction encore actif ne peut pas être désactivé.',
    'INVITATION_ALREADY_PENDING':
        'Une invitation est déjà en attente pour cette adresse. Utilisez « Renvoyer ».',
    'INVITATION_REVOKED':
        'Cette invitation a été annulée. Envoyez-en une nouvelle.',
    'INVITATION_ALREADY_ACCEPTED': 'Cette personne a déjà rejoint le cabinet.',
    'INVITATION_EXPIRED': 'Cette invitation a expiré. Renvoyez-la.',
    'USER_ALREADY_MEMBER': 'Cette personne fait déjà partie du cabinet.',
    'LABEL_NOT_FOUND': 'Étiquette introuvable.',
    'LABEL_RECALLED': 'Cette étiquette a été rappelée : ne pas l\'utiliser.',
    'LABEL_VOIDED': 'Cette étiquette a été annulée : ne pas l\'utiliser.',
    'LABEL_EXPIRED': 'Cette étiquette a dépassé sa date limite d\'utilisation.',
    'LABEL_NOT_USABLE':
        'Une étiquette rappelée ou annulée ne peut pas être liée à un acte.',
    'LABEL_NOT_PRINTED':
        'Imprimez l\'étiquette avant de l\'associer à un acte.',
    'LABEL_NOT_PRINTABLE':
        'Cette étiquette ne peut plus être imprimée (déjà utilisée, expirée, rappelée ou annulée).',
    'LABEL_USAGE_ALREADY_RECORDED':
        'Cette étiquette est déjà associée à un acte.',
    'CYCLE_LOAD_LOCKED':
        'La charge ne peut être modifiée que tant que le cycle est en brouillon.',
    'CYCLE_LOAD_EMPTY': 'Ajoutez au moins un instrument avant de démarrer.',
    'CYCLE_INVALID_TRANSITION':
        'Cette étape n\'est pas possible dans l\'état actuel du cycle.',
    'CYCLE_NOT_RELEASED':
        'Le cycle doit être libéré comme conforme avant de générer les étiquettes.',
    'CYCLE_LABELS_ALREADY_GENERATED':
        'Les étiquettes de ce cycle ont déjà été générées.',
    'DEVICE_NOT_ACTIVE': 'Cet appareil n\'est pas actif.',
    'RECEIPT_EXCEEDS_ORDERED':
        'La quantité reçue dépasse ce qui reste à réceptionner sur la ligne.',
    'BATCH_EXPIRY_MISMATCH':
        'Ce numéro de lot existe déjà avec une autre date de péremption. Vérifiez le lot et la date.',
    'BATCH_QUARANTINED':
        'Ce lot est en quarantaine : il ne peut ni sortir ni recevoir de stock.',
    'LOCATION_ARCHIVED':
        'Cet emplacement est archivé : il ne peut plus recevoir de stock.',
    'EXPIRED_BATCH_REASON_REQUIRED':
        'Ce lot est périmé. Indiquez un motif (par exemple « mise au rebut »).',
    'CODE_NOT_FOUND': 'Aucun produit ni lot ne correspond à ce code.',
    'ATTACHMENT_LIMIT_REACHED':
        'Le nombre maximal de justificatifs est atteint pour cette réception.',
    'INVENTORY_COUNT_ALREADY_OPEN':
        'Un inventaire est déjà ouvert pour cet emplacement.',
    'INVENTORY_COUNT_NOT_OPEN': 'Cet inventaire n\'est plus ouvert.',
    'INVENTORY_COUNT_UNCOUNTED_STOCK':
        'Des lots en stock n\'ont pas été comptés. Comptez-les ou confirmez qu\'ils restent inchangés.',
    'INVENTORY_COUNT_LINE_STALE':
        'Un lot a bougé depuis son comptage. Recomptez-le avant de terminer.',
    'IDEMPOTENCY_IN_PROGRESS':
        'Cette action est déjà en cours. Réessayez dans un instant.',
    'IDEMPOTENCY_KEY_REUSED':
        'Cette action a déjà été envoyée avec des données différentes.',
  };

  static String from(Object error) {
    if (error is DioException) {
      return from(ErrorMapper.fromDio(error));
    }
    if (error is ApiException) {
      final known = _frenchByCode[error.code.toUpperCase()];
      if (known != null) return known;
      // If the API gave us a real French message, use it.
      if (error.message.isNotEmpty) return error.message;
      // Otherwise fall back to a friendly default per code.
      switch (error.code) {
        case 'unauthenticated':
          return 'Session expirée. Veuillez vous reconnecter.';
        case 'forbidden':
          return 'Accès refusé.';
        case 'not_found':
          return 'Ressource introuvable.';
        case 'validation_error':
          return 'Données invalides. Vérifiez les champs.';
        case 'conflict':
          return 'Conflit détecté — la donnée existe déjà.';
        case 'rate_limited':
          return 'Trop de requêtes. Réessayez dans un instant.';
        case 'server_error':
          return 'Erreur serveur. Réessayez plus tard.';
        case 'network_error':
          return 'Connexion impossible. Vérifiez votre réseau.';
        case 'timeout':
          return 'Délai dépassé. Réessayez.';
        default:
          return 'Une erreur est survenue.';
      }
    }
    // If it\'s a raw string like "ApiException(...)" — strip the boilerplate.
    final s = error.toString();
    final m = RegExp(r'message:\s*([^,)]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    return 'Une erreur est survenue. Réessayez.';
  }
}
