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

  bool get isUnauthenticated => code == 'unauthenticated';
  bool get isForbidden => code == 'forbidden';
  bool get isNotFound => code == 'not_found';
  bool get isConflict => code == 'conflict';
  bool get isValidation => code == 'validation_error';
  bool get isRateLimited => code == 'rate_limited';
  bool get isNetwork => code == 'network_error';
  bool get isTimeout => code == 'timeout';

  @override
  String toString() =>
      'ApiException(code: $code, message: $message, status: $statusCode, requestId: $requestId)';
}
