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
}
