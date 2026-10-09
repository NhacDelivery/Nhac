import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';

bool rejeicaoDefinitiva(Object error) {
  final status = error is DioException
      ? error.response?.statusCode
      : error is AppException
      ? error.statusCode
      : null;
  return status != null && status >= 400 && status < 500 && status != 408;
}

bool recursoExcluido(Object error) => error is DioException
    ? error.response?.statusCode == 404 || error.response?.statusCode == 410
    : error is AppException &&
          (error.statusCode == 404 || error.statusCode == 410);
