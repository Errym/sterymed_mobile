import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/core/errors/error_mapper.dart';

void main() {
  group('ErrorMapper.fromDio', () {
    RequestOptions opts() => RequestOptions(path: '/test');

    test('maps connectionTimeout to timeout', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionTimeout,
      );
      final result = ErrorMapper.fromDio(e);
      expect(result.code, ErrorCodes.timeout);
      expect(result.message, isNotEmpty);
    });

    test('maps sendTimeout to timeout', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.sendTimeout,
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.timeout);
    });

    test('maps receiveTimeout to timeout', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.receiveTimeout,
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.timeout);
    });

    test('maps connectionError to network_error', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionError,
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.networkError);
    });

    test('maps 401 to unauthenticated', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts(),
          statusCode: 401,
        ),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.unauthenticated);
    });

    test('maps 403 to forbidden', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 403),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.forbidden);
    });

    test('maps 404 to not_found', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 404),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.notFound);
    });

    test('maps 409 to conflict', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 409),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.conflict);
    });

    test('maps 422 to validation_error', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 422),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.validationError);
    });

    test('maps 429 to rate_limited', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 429),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.rateLimited);
    });

    test('maps 500 to server_error', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 500),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.serverError);
    });

    test('parses server error envelope', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts(),
          statusCode: 422,
          data: {
            'error': {
              'code': 'VALIDATION_FAILED',
              'message': 'Le motif est obligatoire.',
              'details': {'reason': ['Requis']},
              'request_id': 'req-123',
            }
          },
        ),
      );
      final result = ErrorMapper.fromDio(e);
      expect(result.code, 'VALIDATION_FAILED');
      expect(result.message, 'Le motif est obligatoire.');
      expect(result.details['reason'], isA<List>());
      expect(result.requestId, 'req-123');
      expect(result.statusCode, 422);
    });

    test('handles response without error envelope', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts(),
          statusCode: 418,
          data: 'not json',
        ),
      );
      final result = ErrorMapper.fromDio(e);
      expect(result.statusCode, 418);
      expect(result.message, isNotEmpty);
    });
  });
}
