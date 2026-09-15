import 'package:dio/dio.dart';

abstract final class DioFactory {
  static Dio bare() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}
