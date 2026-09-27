import 'error_codes.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> details;
  final String? requestId;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.details = const {},
    this.requestId,
    this.statusCode,
  });

  // The real backend (app/Support/Api/ApiExceptionRenderer.php) always
  // sends UPPER_SNAKE_CASE codes for a genuine server response —
  // UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, CONFLICT, VALIDATION_FAILED,
  // TOO_MANY_REQUESTS — never the lowercase ErrorCodes constants below,
  // which ErrorMapper only ever assigns itself, on the *local* fallback
  // path (no envelope in the response, or a connectivity-level failure).
  // Comparing against the lowercase constant here would never match a
  // real server response; compare case-insensitively against both the
  // renderer's real code and the local fallback so this getter means
  // what its name says regardless of which path produced the exception.
  bool get isUnauthenticated =>
      _matches(code, ErrorCodes.unauthenticated, 'UNAUTHENTICATED');
  bool get isForbidden => _matches(code, ErrorCodes.forbidden, 'FORBIDDEN');
  bool get isNotFound => _matches(code, ErrorCodes.notFound, 'NOT_FOUND');
  bool get isConflict => _matches(code, ErrorCodes.conflict, 'CONFLICT');
  bool get isValidation =>
      _matches(code, ErrorCodes.validationError, 'VALIDATION_FAILED');
  bool get isRateLimited =>
      _matches(code, ErrorCodes.rateLimited, 'TOO_MANY_REQUESTS');
  bool get isNetwork => code == ErrorCodes.networkError;
  bool get isTimeout => code == ErrorCodes.timeout;

  static bool _matches(String code, String localCode, String realCode) =>
      code == localCode || code.toUpperCase() == realCode;

  @override
  String toString() =>
      'ApiException(code: $code, message: $message, status: $statusCode, requestId: $requestId)';
}
