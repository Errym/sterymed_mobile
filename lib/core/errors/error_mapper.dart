import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'error_codes.dart';

abstract final class ErrorMapper {
  static ApiException fromDio(DioException e) {
    // No response → network / timeout
    if (e.response == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException(
            code: ErrorCodes.timeout,
            message: 'Le délai de connexion a expiré. Vérifiez votre réseau et réessayez.',
          );
        case DioExceptionType.connectionError:
          return const ApiException(
            code: ErrorCodes.networkError,
            message: 'Connexion impossible. Vérifiez votre réseau.',
          );
        default:
          return const ApiException(
            code: ErrorCodes.networkError,
            message: 'Une erreur réseau est survenue.',
          );
      }
    }

    // Server error envelope
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: err['code']?.toString() ?? _codeForStatus(e.response?.statusCode),
        message:
            err['message']?.toString() ??
            _fallbackMessage(e.response?.statusCode),
        details: (err['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        requestId: err['request_id']?.toString(),
        statusCode: e.response?.statusCode,
      );
    }

    // Fallback
    return ApiException(
      code: _codeForStatus(e.response?.statusCode),
      message: _fallbackMessage(e.response?.statusCode),
      statusCode: e.response?.statusCode,
    );
  }

  static String _codeForStatus(int? status) {
    switch (status) {
      case 401:
        return ErrorCodes.unauthenticated;
      case 403:
        return ErrorCodes.forbidden;
      case 404:
        return ErrorCodes.notFound;
      case 409:
        return ErrorCodes.conflict;
      case 422:
        return ErrorCodes.validationError;
      case 429:
        return ErrorCodes.rateLimited;
      case 500:
      case 502:
      case 503:
      case 504:
        return ErrorCodes.serverError;
      default:
        return ErrorCodes.unknown;
    }
  }

  static String _fallbackMessage(int? status) {
    switch (status) {
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 403:
        return 'Accès refusé.';
      case 404:
        return 'Ressource introuvable.';
      case 409:
        return 'Conflit détecté.';
      case 422:
        return 'Données invalides.';
      case 429:
        return 'Trop de requêtes. Réessayez dans un instant.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Erreur serveur. Réessayez plus tard.';
      default:
        return 'Une erreur est survenue.';
    }
  }
}
