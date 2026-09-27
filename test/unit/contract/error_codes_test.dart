// Task 3.4: "asserts every ErrorCodes constant is reachable from at least
// one interceptor path." test/unit/core/error_mapper_test.dart already
// proves reachability from the *local fallback* path (no envelope, or an
// unmapped status — ErrorMapper._codeForStatus assigns the lowercase
// ErrorCodes constant itself). What neither that file nor anything else
// tested is the *other* interceptor path: a real backend envelope.
//
// Verified directly against app/Support/Api/ApiExceptionRenderer.php
// (steriqore) before writing this — every real server error is
// UPPER_SNAKE_CASE (UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, CONFLICT,
// VALIDATION_FAILED, TOO_MANY_REQUESTS, METHOD_NOT_ALLOWED, GONE,
// INTERNAL_ERROR, HTTP_{status}), never the lowercase ErrorCodes
// constant. Found and fixed a real bug via this test: ApiException's
// convenience getters (isUnauthenticated, isForbidden, ...) compared only
// against the lowercase local constant, so they could never be true for
// a genuine server response — 0 call sites today, so no live behavior
// bug yet, but exactly the landmine this test exists to catch before one
// is added.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/core/errors/error_mapper.dart';

ApiException _fromRealEnvelope(int status, String code, {String? message}) {
  final opts = RequestOptions(path: '/test');
  return ErrorMapper.fromDio(DioException(
    requestOptions: opts,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: opts,
      statusCode: status,
      data: {
        'error': {
          'code': code,
          'message': message ?? 'x',
          'details': <String, dynamic>{},
          'request_id': 'req-1',
        },
      },
    ),
  ));
}

void main() {
  group(
    'ApiException getters recognize the real backend envelope, not just '
    "ErrorMapper's own local fallback code",
    () {
      test('UNAUTHENTICATED (real) -> isUnauthenticated', () {
        expect(_fromRealEnvelope(401, 'UNAUTHENTICATED').isUnauthenticated,
            isTrue);
      });

      test('FORBIDDEN (real) -> isForbidden', () {
        expect(_fromRealEnvelope(403, 'FORBIDDEN').isForbidden, isTrue);
      });

      test('NOT_FOUND (real) -> isNotFound', () {
        expect(_fromRealEnvelope(404, 'NOT_FOUND').isNotFound, isTrue);
      });

      test('CONFLICT (real) -> isConflict', () {
        expect(_fromRealEnvelope(409, 'CONFLICT').isConflict, isTrue);
      });

      test('VALIDATION_FAILED (real, not "validation_error") -> isValidation',
          () {
        expect(
          _fromRealEnvelope(422, 'VALIDATION_FAILED').isValidation,
          isTrue,
        );
      });

      test(
        'TOO_MANY_REQUESTS (real, not "rate_limited") -> isRateLimited',
        () {
          expect(
            _fromRealEnvelope(429, 'TOO_MANY_REQUESTS').isRateLimited,
            isTrue,
          );
        },
      );

      test('the local fallback code still matches too (unchanged behavior)',
          () {
        const local = ApiException(
          code: ErrorCodes.validationError,
          message: 'x',
        );
        expect(local.isValidation, isTrue);
      });

      test('a domain-specific code (e.g. LABEL_EXPIRED) matches none of the '
          'generic getters — those are compared directly by callers, by '
          'design', () {
        final e = _fromRealEnvelope(410, 'LABEL_EXPIRED');
        expect(e.isUnauthenticated, isFalse);
        expect(e.isForbidden, isFalse);
        expect(e.isNotFound, isFalse);
        expect(e.isConflict, isFalse);
        expect(e.isValidation, isFalse);
        expect(e.isRateLimited, isFalse);
        expect(e.code, 'LABEL_EXPIRED');
      });
    },
  );

  test(
    'ErrorCodes.unknown is reachable for a status ErrorMapper does not map '
    '(e.g. 418) — a real gap: this path existed but nothing ever asserted '
    'the resulting code, only the message and status',
    () {
      final opts = RequestOptions(path: '/test');
      final e = ErrorMapper.fromDio(DioException(
        requestOptions: opts,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts, statusCode: 418),
      ));
      expect(e.code, ErrorCodes.unknown);
    },
  );
}
