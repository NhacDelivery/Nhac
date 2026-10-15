import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/repositories/chat_repository.dart';

class MockChatDio extends Mock implements Dio {}

Map<String, dynamic> conversa(String id, String tipo) => {
      'id': id,
      'tipo': tipo,
      'interlocutor': {
        'id': '$id-destino',
        'nome': '$id nome',
        'imagemUrl': null
      },
      'ultimaMensagemPreview': 'Mensagem $id',
      'ultimaMensagemEm': '2026-10-09T22:30:00Z',
      'naoLidas': 3,
    };

void responder(
  MockChatDio dio,
  int page,
  List<Map<String, dynamic>> items, {
  bool last = true,
}) {
  when(
    () => dio.get('/conversas', queryParameters: {'page': page, 'size': 100}),
  ).thenAnswer(
    (_) async => Response(
      requestOptions: RequestOptions(path: '/conversas'),
      data: {'content': items, 'last': last},
    ),
  );
}

void main() {
  test('fallback REST conserva identificador e devolve mensagem confirmada',
      () async {
    final dio = MockChatDio();
    const id = '123e4567-e89b-12d3-a456-426614174000';
    when(() => dio.post('/conversas/conversa/mensagens', data: {
              'conteudo': 'Olá',
              'clientMessageId': id,
            }))
        .thenAnswer((_) async =>
            Response(requestOptions: RequestOptions(path: '/chat'), data: {
              'id': 'msg_$id',
              'conversaId': 'conversa',
              'remetenteTipo': 'CLIENTE',
              'remetenteUsuarioId': 'eu',
              'conteudo': 'Olá',
              'enviadaEm': '2026-10-15T12:00:00Z',
            }));
    final mensagem = await ChatRepository(dio: dio)
        .enviarMensagem('conversa', conteudo: 'Olá', clientMessageId: id);
    expect(mensagem.id, 'msg_$id');
    expect(mensagem.remetenteUsuarioId, 'eu');
    verify(() => dio.post('/conversas/conversa/mensagens',
        data: {'conteudo': 'Olá', 'clientMessageId': id})).called(1);
  });

  test(
    'lista lojas pelo contrato de conversas, sem misturar pessoas',
    () async {
      final dio = MockChatDio();
      responder(dio, 0, [
        conversa('pessoa', 'CLIENTE'),
        conversa('loja', 'LOJA'),
      ]);
      final result = await ChatRepository(dio: dio).listarConversas();
      expect(result.single.id, 'loja');
      expect(result.single.lojaId, 'loja-destino');
      expect(result.single.lojaNome, 'loja nome');
      expect(result.single.ultimaMensagem, 'Mensagem loja');
      expect(result.single.mensagensNaoLidas, 3);
      expect(
        result.single.ultimaMensagemData.toUtc(),
        DateTime.parse('2026-10-09T22:30:00Z'),
      );
      verify(
        () => dio.get('/conversas', queryParameters: {'page': 0, 'size': 100}),
      ).called(1);
      verifyNoMoreInteractions(dio);
    },
  );

  test('lista pessoas usando interlocutor e não o catálogo de lojas', () async {
    final dio = MockChatDio();
    responder(dio, 0, [
      conversa('loja', 'LOJA'),
      conversa('pessoa', 'CLIENTE'),
    ]);
    final result = await ChatRepository(dio: dio).listarConversasPessoas();
    expect(result.single.id, 'pessoa');
    expect(result.single.pessoaId, 'pessoa-destino');
    expect(result.single.pessoaNome, 'pessoa nome');
    expect(result.single.ultimaMensagem, 'Mensagem pessoa');
    expect(result.single.mensagensNaoLidas, 3);
    expect(
      result.single.ultimaMensagemData.toUtc(),
      DateTime.parse('2026-10-09T22:30:00Z'),
    );
  });

  test(
    'não retorna lista vazia quando a primeira página só tem outro tipo',
    () async {
      final dio = MockChatDio();
      responder(dio, 0, [conversa('loja', 'LOJA')], last: false);
      responder(dio, 1, [conversa('pessoa', 'CLIENTE')]);
      final result = await ChatRepository(dio: dio).listarConversasPessoas();
      expect(result.single.id, 'pessoa');
      verify(
        () => dio.get('/conversas', queryParameters: {'page': 1, 'size': 100}),
      ).called(1);
    },
  );

  test('pagina as conversas do tipo solicitado sem repetir itens', () async {
    final dio = MockChatDio();
    responder(
        dio,
        0,
        [
          conversa('primeira', 'LOJA'),
          conversa('pessoa', 'CLIENTE'),
        ],
        last: false);
    responder(dio, 1, [conversa('segunda', 'LOJA')]);
    final result =
        await ChatRepository(dio: dio).listarConversas(pagina: 1, tamanho: 1);
    expect(result.single.id, 'segunda');
  });

  test('propaga falha HTTP sem apresentar a caixa como vazia', () async {
    final dio = MockChatDio();
    when(() => dio.get('/conversas', queryParameters: {'page': 0, 'size': 100}))
        .thenThrow(
      DioException.connectionError(
        requestOptions: RequestOptions(path: '/conversas'),
        reason: 'offline',
      ),
    );
    await expectLater(
      ChatRepository(dio: dio).listarConversasPessoas(),
      throwsA(isA<Exception>()),
    );
  });
}
