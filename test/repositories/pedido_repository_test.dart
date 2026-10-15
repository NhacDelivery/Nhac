import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late PedidoRepository repository;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    when(() => dio.options).thenReturn(BaseOptions());
    repository = PedidoRepository(dio: dio);
  });

  CriarPedidoRequest request() => CriarPedidoRequest(
        lojaId: 'loja1',
        formaPagamento: 'DINHEIRO',
        enderecoEntrega: EnderecoModel(
          rua: 'Rua A',
          numero: '1',
          bairro: 'Centro',
          cidade: 'Osasco',
          estado: 'SP',
          cep: '06000-000',
        ),
        itens: const [
          CriarPedidoItemRequest(
            produtoId: 'prod1',
            nome: 'Produto',
            quantidade: 1,
          ),
        ],
      );

  test('pedido envia coordenadas do endereço usadas no frete', () {
    final pedido = CriarPedidoRequest(
      lojaId: 'loja1',
      formaPagamento: 'PIX',
      enderecoEntrega: EnderecoModel(
          rua: 'Rua A',
          numero: '1',
          bairro: 'Centro',
          cidade: 'Osasco',
          estado: 'SP',
          cep: '06000-000'),
      entregaLatitude: -23.5,
      entregaLongitude: -46.7,
      itens: const [
        CriarPedidoItemRequest(
            produtoId: 'prod1', nome: 'Produto', quantidade: 1)
      ],
    );
    final endereco = pedido.toMap()['enderecoEntrega'] as Map<String, dynamic>;
    expect(endereco['latitude'], -23.5);
    expect(endereco['longitude'], -46.7);
  });

  test(
      'reserva confirmada com gateway indisponível abre recuperação sem novo POST',
      () async {
    when(() => dio.post('/pedidos',
        data: any(named: 'data'),
        options: any(named: 'options'))).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/pedidos'),
      response: Response(
          requestOptions: RequestOptions(path: '/pedidos'),
          statusCode: 409,
          data: {
            'error': 'PAGAMENTO_INDISPONIVEL',
            'details': {'pedidoId': 'reservado'}
          }),
    ));
    final resposta =
        await repository.finalizarPedido(request(), idempotencyKey: 'idem-1');
    expect(resposta.pedidoId, 'reservado');
    expect(resposta.replay, isTrue);
    verify(() => dio.post('/pedidos',
        data: any(named: 'data'), options: any(named: 'options'))).called(1);
  });

  test('POST /pedidos envia Idempotency-Key', () async {
    when(() => dio.post(
          '/pedidos',
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/pedidos'),
        statusCode: 201,
        data: {'pedidoId': 'ped1'},
      ),
    );

    final response = await repository.finalizarPedido(
      request(),
      idempotencyKey: 'idem-123',
    );

    expect(response.pedidoId, 'ped1');
    expect(response.replay, isFalse);

    final captured = verify(() => dio.post(
          '/pedidos',
          data: any(named: 'data'),
          options: captureAny(named: 'options'),
        )).captured;
    final options = captured.single as Options;
    expect(options.headers?['Idempotency-Key'], 'idem-123');
  });

  test('HTTP 200 é identificado como replay idempotente', () async {
    when(() => dio.post(
          '/pedidos',
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/pedidos'),
        statusCode: 200,
        data: {'pedidoId': 'ped1'},
      ),
    );

    final response = await repository.finalizarPedido(
      request(),
      idempotencyKey: 'idem-123',
    );

    expect(response.replay, isTrue);
  });

  test('409 de idempotência preserva o código de conflito', () async {
    when(() => dio.post(
          '/pedidos',
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/pedidos'),
        response: Response(
          requestOptions: RequestOptions(path: '/pedidos'),
          statusCode: 409,
          data: {
            'error': 'IDEMPOTENCIA_CONFLITO',
            'message': 'A Idempotency-Key já foi usada com outro pedido.',
          },
        ),
      ),
    );

    try {
      await repository.finalizarPedido(
        request(),
        idempotencyKey: 'idem-123',
      );
      fail('Era esperado CustomCheckoutException');
    } on CustomCheckoutException catch (e) {
      expect(e.code, 'IDEMPOTENCIA_CONFLITO');
      expect(e.title, 'Checkout alterado');
    }
  });

  test('histórico usa a rota canônica GET /pedidos', () async {
    when(() => dio.get(
          '/pedidos',
          queryParameters: {
            'page': 0,
            'size': 10,
            'sort': 'criadoEm,desc',
          },
        )).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/pedidos'),
        statusCode: 200,
        data: {
          'content': [
            {
              'id': 'ped1',
              'lojaId': 'loja1',
              'lojaNome': 'Nhac',
              'valorTotal': 20,
              'status': 'PAGO',
              'criadoEm': '2026-09-20T10:00:00Z',
            }
          ]
        },
      ),
    );

    final pedidos = await repository.buscarHistorico();
    expect(pedidos, hasLength(1));
    expect(pedidos.single.id, 'ped1');
  });

  test('pedido ativo 204 não usa histórico paginado', () async {
    when(() => dio.get('/pedidos/ativo')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/pedidos/ativo'),
          statusCode: 204,
        ));
    expect(await repository.buscarPedidoAtivo(), isNull);
    verify(() => dio.get('/pedidos/ativo')).called(1);
  });

  test('pagamento pendente recupera o mesmo PIX e prazo', () async {
    when(() => dio.get('/pedidos/ped1/pagamento'))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/pedidos/ped1/pagamento'),
              statusCode: 200,
              data: {
                'pedidoId': 'ped1',
                'formaPagamento': 'PIX',
                'status': 'PENDENTE',
                'valorTotal': 25.5,
                'expiraEm': '2026-09-29T13:00:00Z',
                'pixCopiaECola': '000201...',
                'qrCodeUrl': '000201...',
                'simulacaoDisponivel': true,
              },
            ));
    final pagamento = await repository.buscarPagamento('ped1');
    expect(pagamento.pixCopiaECola, '000201...');
    expect(pagamento.valorTotal, 25.5);
    expect(pagamento.simulacaoDisponivel, isTrue);
  });

  test('409 PEDIDO_ATIVO expõe o pedido para recuperar o fluxo', () async {
    when(() => dio.post('/pedidos',
        data: any(named: 'data'),
        options: any(named: 'options'))).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/pedidos'),
      response: Response(
          requestOptions: RequestOptions(path: '/pedidos'),
          statusCode: 409,
          data: {
            'error': 'PEDIDO_ATIVO',
            'message': 'Finalize seu pedido atual.',
            'details': {'pedidoId': 'ped-antigo'},
          }),
    ));
    try {
      await repository.finalizarPedido(request(), idempotencyKey: 'idem-2');
      fail('Era esperado PEDIDO_ATIVO');
    } on CustomCheckoutException catch (e) {
      expect(e.code, 'PEDIDO_ATIVO');
      expect(e.pedidoAtivoId, 'ped-antigo');
    }
  });

  test('POST /pedidos/{id}/avaliacao-entregador envia nota e comentário',
      () async {
    when(() => dio.post(
          '/pedidos/ped-123/avaliacao-entregador',
          data: any(named: 'data'),
        )).thenAnswer(
      (_) async => Response(
        requestOptions:
            RequestOptions(path: '/pedidos/ped-123/avaliacao-entregador'),
        statusCode: 201,
      ),
    );

    await repository.avaliarEntregador('ped-123', 5, 'Excelente entrega');

    verify(() => dio.post(
          '/pedidos/ped-123/avaliacao-entregador',
          data: {'nota': 5, 'comentario': 'Excelente entrega'},
        )).called(1);
  });

  test('GET /pedidos/{id}/avaliacao-entregador retorna modelo em caso de 200',
      () async {
    when(() => dio.get('/pedidos/ped-123/avaliacao-entregador')).thenAnswer(
      (_) async => Response(
        requestOptions:
            RequestOptions(path: '/pedidos/ped-123/avaliacao-entregador'),
        statusCode: 200,
        data: {
          'id': 'aval-1',
          'nota': 5,
          'comentario': 'Muito rápido!',
          'criadoEm': '2026-09-30T10:00:00Z',
        },
      ),
    );

    final avaliacao = await repository.buscarAvaliacaoEntregador('ped-123');
    expect(avaliacao, isNotNull);
    expect(avaliacao!.id, 'aval-1');
    expect(avaliacao.nota, 5);
    expect(avaliacao.comentario, 'Muito rápido!');
  });

  test('GET /pedidos/{id}/avaliacao-entregador retorna null em caso de 404',
      () async {
    when(() => dio.get('/pedidos/ped-123/avaliacao-entregador')).thenThrow(
      DioException(
        requestOptions:
            RequestOptions(path: '/pedidos/ped-123/avaliacao-entregador'),
        response: Response(
          requestOptions:
              RequestOptions(path: '/pedidos/ped-123/avaliacao-entregador'),
          statusCode: 404,
        ),
      ),
    );

    final avaliacao = await repository.buscarAvaliacaoEntregador('ped-123');
    expect(avaliacao, isNull);
  });
  test('estatísticas falhando não retornam zeros válidos', () async {
    when(() =>
        dio.get('/usuarios/estat-falha/estatisticas',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'))).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/estatisticas')));
    await expectLater(
        repository.buscarEstatisticas('estat-falha'), throwsException);
  });

  test('estatísticas realmente zeradas são aceitas', () async {
    when(() => dio.get('/usuarios/estat-zero/estatisticas',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'))).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/estatisticas'),
            statusCode: 200,
            data: {
              'totalPedidos': 0,
              'lojasFavoritadas': 0,
              'cuponsResgatados': 0
            }));
    expect(
        (await repository.buscarEstatisticas('estat-zero'))['totalPedidos'], 0);
  });
  test('atualização explícita de estatísticas não reaproveita contagem antiga',
      () async {
    var total = 1;
    when(() => dio.get('/usuarios/estat-refresh/estatisticas',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'))).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/estatisticas'),
            statusCode: 200,
            data: {
              'totalPedidos': total,
              'lojasFavoritadas': 0,
              'cuponsResgatados': 0
            }));
    expect(
        (await repository.buscarEstatisticas('estat-refresh'))['totalPedidos'],
        1);
    total = 2;
    expect(
        (await repository.buscarEstatisticas('estat-refresh'))['totalPedidos'],
        2);
    verify(() => dio.get('/usuarios/estat-refresh/estatisticas',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'))).called(2);
  });
}
