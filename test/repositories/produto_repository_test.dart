import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/produto_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ProdutoRepository repository;

  setUp(() {
    dio = MockDio();
    repository = ProdutoRepository(dio: dio);
  });

  void responderPagina(int pagina, Map<String, dynamic> data) {
    when(() => dio.get('/produtos', queryParameters: {
          'lojaId': 'loja-1',
          'page': pagina,
          'size': 50,
          'sort': 'id,asc',
        })).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/produtos'),
          data: data,
          statusCode: 200,
        ));
  }

  test('carrega o cardápio completo usando a paginação do backend', () async {
    responderPagina(0, {
      'content': [
        {'id': 'produto-1', 'lojaId': 'loja-1'}
      ],
      'last': false,
    });
    responderPagina(1, {
      'content': [
        {'id': 'produto-2', 'lojaId': 'loja-1'}
      ],
      'last': true,
    });

    final produtos = await repository.buscarPorLoja('loja-1');

    expect(produtos.map((p) => p.id), ['produto-1', 'produto-2']);
    verify(() => dio.get('/produtos',
        queryParameters: any(named: 'queryParameters'))).called(2);
  });

  test('encerra a busca quando a loja tem um cardápio vazio', () async {
    responderPagina(0, {'content': [], 'last': true});

    expect(await repository.buscarPorLoja('loja-1'), isEmpty);
    verify(() => dio.get('/produtos',
        queryParameters: any(named: 'queryParameters'))).called(1);
  });
}
