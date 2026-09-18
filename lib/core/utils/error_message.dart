import '../errors/api_exception.dart';

/// Turn an exception object into a clean, user-facing French string.
/// The API already returns French messages — we strip the boilerplate
/// `ApiException(code: ..., status: ...)` wrapper and keep just the message.
abstract final class ErrorMessage {
  static String from(Object error) {
    if (error is ApiException) {
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
    // If it's a raw string like "ApiException(...)" — strip the boilerplate.
    final s = error.toString();
    final m = RegExp(r'message:\s*([^,)]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    return s;
  }
}
