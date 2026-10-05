import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/services/shared_get.dart';

class CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  final replies = <Completer<ResponseBody>>[];
  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) {
    calls++;
    final reply = Completer<ResponseBody>();
    replies.add(reply);
    return reply.future;
  }

  void reply(int index, String body, {int status = 200}) =>
      replies[index].complete(ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: ['application/json']
      }));
  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late CountingAdapter adapter;
  late SharedGet client;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = CountingAdapter();
    dio.httpClientAdapter = adapter;
    client = SharedGet.forClient(dio);
  });
  Future<void> dispatch() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test(
      'operações equivalentes compartilham rede e cache; parâmetros distinguem páginas',
      () async {
    final a =
        client.get(dio, '/produtos', queryParameters: {'page': 0, 'size': 50});
    final b =
        client.get(dio, '/produtos', queryParameters: {'size': 50, 'page': 0});
    expect(identical(a, b), isTrue);
    await dispatch();
    expect(adapter.calls, 1);
    adapter.reply(0, '{"content":[]}');
    await Future.wait([a, b]);
    await client
        .get(dio, '/produtos', queryParameters: {'page': 0, 'size': 50});
    expect(adapter.calls, 1);
    final page =
        client.get(dio, '/produtos', queryParameters: {'page': 1, 'size': 50});
    await dispatch();
    expect(adapter.calls, 2);
    adapter.reply(1, '{}');
    await page;
  });

  test('invalidação descarta cache da resposta antiga sem apagar operação nova',
      () async {
    final old = client.get(dio, '/pedidos/p1');
    await dispatch();
    client.invalidate();
    final fresh = client.get(dio, '/pedidos/p1');
    await dispatch();
    adapter.reply(1, '{"status":"PREPARANDO"}');
    await fresh;
    adapter.reply(0, '{"status":"PAGO"}');
    await old;
    final cached = await client.get(dio, '/pedidos/p1');
    expect(cached.data['status'], 'PREPARANDO');
    expect(adapter.calls, 2);
  });

  test('invalidar pedidos preserva o cache de um catálogo em voo', () async {
    final catalogo = client.get(dio, '/produtos/cards');
    await dispatch();
    client.invalidatePrefix('/pedidos');
    adapter.reply(0, '{"content":[]}');
    await catalogo;
    await client.get(dio, '/produtos/cards');
    expect(adapter.calls, 1);
  });

  test('invalidação de caminho impede que a resposta antiga repovoe o cache',
      () async {
    final antiga = client.get(dio, '/pedidos/p1');
    await dispatch();
    client.invalidatePath('/pedidos/p1');
    final nova = client.get(dio, '/pedidos/p1');
    await dispatch();
    adapter.reply(1, '{"status":"PREPARANDO"}');
    await nova;
    adapter.reply(0, '{"status":"PAGO"}');
    await antiga;
    expect((await client.get(dio, '/pedidos/p1')).data['status'], 'PREPARANDO');
    expect(adapter.calls, 2);
  });

  test('sessões e pedidos distintos nunca compartilham dados', () async {
    final first = client.get(dio, '/pedidos/p1');
    await dispatch();
    adapter.reply(0, '{}');
    await first;
    SharedGet.newSession();
    final second = client.get(dio, '/pedidos/p1');
    final otherOrder = client.get(dio, '/pedidos/p2');
    await dispatch();
    expect(adapter.calls, 3);
    adapter.reply(1, '{}');
    adapter.reply(2, '{}');
    await Future.wait([second, otherOrder]);
  });

  test('erro não inicia retry automático; cache expirado exige nova rede',
      () async {
    final failure = client.get(dio, '/pedidos/ativos');
    final expectation = expectLater(failure, throwsA(isA<DioException>()));
    await dispatch();
    adapter.reply(0, '{}', status: 500);
    await expectation;
    await dispatch();
    expect(adapter.calls, 1);
    final retry = client.get(dio, '/pedidos/ativos', validity: Duration.zero);
    await dispatch();
    adapter.reply(1, '[]');
    await retry;
    final expired = client.get(dio, '/pedidos/ativos');
    await dispatch();
    expect(adapter.calls, 3);
    adapter.reply(2, '[]');
    await expired;
  });
}
