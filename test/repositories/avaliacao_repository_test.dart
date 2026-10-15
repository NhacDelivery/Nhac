import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/avaliacao_repository.dart';

class AvaliacaoDio extends Mock implements Dio {}

void main() {
  test('falha no resumo não vira avaliação zero', () async {
    final dio = AvaliacaoDio();
    when(() => dio.get('/produtos/p/avaliacoes/resumo')).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/resumo')));
    await expectLater(AvaliacaoRepository(dio: dio).buscarResumoAvaliacoes('p'),
        throwsStateError);
  });
  test('404 dos comentários não vira lista vazia', () async {
    final dio = AvaliacaoDio();
    when(() => dio.get('/lojas/l/avaliacoes',
            queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException(
            requestOptions: RequestOptions(path: '/avaliacoes'),
            response: Response(
                requestOptions: RequestOptions(path: '/avaliacoes'),
                statusCode: 404)));
    await expectLater(
        AvaliacaoRepository(dio: dio).buscarAvaliacoes('l'), throwsException);
  });
}
