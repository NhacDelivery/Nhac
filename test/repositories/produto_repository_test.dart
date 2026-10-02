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
    when(() => dio.options).thenReturn(BaseOptions());
    repository = ProdutoRepository(dio: dio);
  });

  void responderPagina(int pagina, Map<String, dynamic> data) {
    when(
      () => dio.get(
        '/produtos',
        queryParameters: {
          'lojaId': 'loja-1',
          'page': pagina,
          'size': 50,
          'sort': 'id,asc',
        },
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/produtos'),
        data: data,
        statusCode: 200,
      ),
    );
  }

  test(
    'falhas de pesquisa e cardápio propagam erro em vez de lista vazia',
    () async {
      when(
        () => dio.get(
          '/produtos',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(Exception('Sem conexão'));
      await expectLater(
        repository.buscarProdutosPorNome('pizza'),
        throwsException,
      );
      await expectLater(
        repository.buscarPorCategoria('Bebidas'),
        throwsException,
      );
      await expectLater(repository.buscarPorLoja('l1'), throwsException);
    },
  );

  test('carrega o cardápio completo usando a paginação do backend', () async {
    responderPagina(0, {
      'content': [
        {'id': 'produto-1', 'lojaId': 'loja-1'},
      ],
      'last': false,
    });
    responderPagina(1, {
      'content': [
        {'id': 'produto-2', 'lojaId': 'loja-1'},
      ],
      'last': true,
    });

    final produtos = await repository.buscarPorLoja('loja-1');

    expect(produtos.map((p) => p.id), ['produto-1', 'produto-2']);
    verify(
      () =>
          dio.get('/produtos', queryParameters: any(named: 'queryParameters')),
    ).called(2);
  });

  test('encerra a busca quando a loja tem um cardápio vazio', () async {
    responderPagina(0, {'content': [], 'last': true});

    expect(await repository.buscarPorLoja('loja-1'), isEmpty);
    verify(
      () =>
          dio.get('/produtos', queryParameters: any(named: 'queryParameters')),
    ).called(1);
  });

  test('promoções exigem desconto real mesmo para produto barato', () async {
    when(
      () => dio.get('/produtos/promocoes',
          queryParameters: {'page': 0, 'size': 10, 'sort': 'id,asc'}),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/produtos'),
        data: {
          'content': [
            {'id': 'barato', 'preco': 15, 'percentualDesconto': 0},
            {'id': 'descontado', 'preco': 19.99, 'percentualDesconto': 10},
            {'id': 'limite', 'preco': 20, 'percentualDesconto': 10},
            {'id': 'caro', 'preco': 30, 'percentualDesconto': 10},
            {
              'id': 'fechada',
              'preco': 10,
              'percentualDesconto': 10,
              'lojaAberta': false,
            },
          ],
          'last': true,
        },
        statusCode: 200,
      ),
    );
    final produtos = await repository.buscarPromocoes();
    expect(produtos.map((p) => p.id), ['descontado']);
  });
}
