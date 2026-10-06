import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/utils/request_outcome.dart';

void main() {
  test(
    'rejeição confirmada permite corrigir sem descartar tentativa incerta',
    () {
      expect(
        rejeicaoDefinitiva(AppException('Inválido', statusCode: 422)),
        isTrue,
      );
      expect(
        rejeicaoDefinitiva(AppException('Sem permissão', statusCode: 403)),
        isTrue,
      );
      for (final status in [408, 409, 429, 500, 503]) {
        expect(
          rejeicaoDefinitiva(AppException('Falha', statusCode: status)),
          isFalse,
        );
      }
      expect(
        rejeicaoDefinitiva(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        isFalse,
      );
    },
  );
  test('somente ausência confirmada invalida publicação', () {
    expect(recursoExcluido(AppException('Removido', statusCode: 404)), isTrue);
    expect(recursoExcluido(AppException('Falha', statusCode: 500)), isFalse);
  });
}
