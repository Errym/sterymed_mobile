import 'api_exception.dart';

class Failure {
  final String code;
  final String message;
  final String? requestId;

  const Failure({required this.code, required this.message, this.requestId});

  factory Failure.fromApiException(ApiException e) =>
      Failure(code: e.code, message: e.message, requestId: e.requestId);
}
