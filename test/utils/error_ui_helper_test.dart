import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/globals/exceptions.dart' as legacy;
import 'package:nhac/utils/app_exceptions.dart';
import 'package:nhac/utils/error_ui_helper.dart';

void main() {
  test('banners preservam erro mapeado do repositório', () {
    expect(
        ErrorUIHelper.mensagem(legacy.AppException('Conversa indisponível.')),
        'Conversa indisponível.');
  });
  test('banners preservam regra de negócio tipada do ApiClient', () {
    expect(
        ErrorUIHelper.mensagem(BusinessRuleException('Mensagem muito longa.')),
        'Mensagem muito longa.');
  });
  test('Dio com exceção tipada mantém o texto do servidor', () {
    final error = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        error: ForbiddenException('Você não participa desta conversa.'));
    expect(ErrorUIHelper.mensagem(error), 'Você não participa desta conversa.');
  });
  test('erro técnico desconhecido não aparece na interface', () {
    expect(
        ErrorUIHelper.mensagem(StateError('private SQL detail'),
            fallback: 'Não foi possível abrir a conversa.'),
        'Não foi possível abrir a conversa.');
    expect(legacy.mapException(StateError('private SQL detail')).toString(),
        isNot(contains('SQL')));
  });
}
