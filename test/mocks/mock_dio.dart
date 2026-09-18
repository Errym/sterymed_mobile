import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// Helper to build a successful JSON response.
Response<T> jsonResponse<T>({
  required T data,
  int statusCode = 200,
  RequestOptions? requestOptions,
}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: requestOptions ?? RequestOptions(path: '/'),
  );
}

/// Helper to build a DioException with a status code.
DioException dioError({
  required int statusCode,
  Map<String, dynamic>? data,
  String? path,
}) {
  final opts = RequestOptions(path: path ?? '/');
  return DioException(
    requestOptions: opts,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: opts,
      statusCode: statusCode,
      data: data,
    ),
  );
}
