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

void responder(MockChatDio dio, String tipo, int page,
    List<Map<String, dynamic>> items, {int tamanho = 20}) {
  when(() => dio.get('/conversas', queryParameters: {
    'tipo': tipo, 'page': page, 'size': tamanho,
  })).thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/conversas'),
      data: {'content': items}));
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

  test('lista lojas com filtro e uma única consulta', () async {
    final dio = MockChatDio();
    responder(dio, 'LOJA', 0, [conversa('loja', 'LOJA')]);
    final result = await ChatRepository(dio: dio).listarConversas();
    expect(result.single.lojaId, 'loja-destino');
    expect(result.single.mensagensNaoLidas, 3);
    verify(() => dio.get('/conversas', queryParameters: {'tipo': 'LOJA', 'page': 0, 'size': 20})).called(1);
    verifyNoMoreInteractions(dio);
  });
  test('lista pessoas diretamente na página do tipo solicitado', () async {
    final dio = MockChatDio();
    responder(dio, 'CLIENTE', 5, [conversa('pessoa', 'CLIENTE')]);
    final result = await ChatRepository(dio: dio).listarConversasPessoas(pagina: 5);
    expect(result.single.pessoaNome, 'pessoa nome');
    verify(() => dio.get('/conversas', queryParameters: {'tipo': 'CLIENTE', 'page': 5, 'size': 20})).called(1);
    verifyNoMoreInteractions(dio);
  });
  test('paginação não relê páginas anteriores', () async {
    final dio = MockChatDio();
    responder(dio, 'LOJA', 1, [conversa('segunda', 'LOJA')], tamanho: 1);
    expect((await ChatRepository(dio: dio).listarConversas(pagina: 1, tamanho: 1)).single.id, 'segunda');
    verify(() => dio.get('/conversas', queryParameters: {'tipo': 'LOJA', 'page': 1, 'size': 1})).called(1);
    verifyNoMoreInteractions(dio);
  });
  test('caixa vazia não dispara varredura de outras páginas', () async {
    final dio = MockChatDio(); responder(dio, 'CLIENTE', 0, []);
    expect(await ChatRepository(dio: dio).listarConversasPessoas(), isEmpty);
    verify(() => dio.get('/conversas', queryParameters: {'tipo': 'CLIENTE', 'page': 0, 'size': 20})).called(1);
    verifyNoMoreInteractions(dio);
  });
  test('backend que ignora filtro não pode produzir vazio ou caixa mista silenciosa', () async {
    final dio = MockChatDio(); responder(dio, 'CLIENTE', 0, [conversa('loja', 'LOJA')]);
    await expectLater(ChatRepository(dio: dio).listarConversasPessoas(), throwsA(anything));
  });
  test('parâmetros inválidos não fazem HTTP', () async {
    final dio = MockChatDio(); final repo = ChatRepository(dio: dio);
    await expectLater(repo.listarConversas(pagina: -1), throwsA(anything));
    await expectLater(repo.listarConversas(tamanho: 101), throwsA(anything));
    verifyZeroInteractions(dio);
  });
  test('falha HTTP preserva erro sem virar caixa vazia', () async {
    final dio = MockChatDio();
    when(() => dio.get('/conversas', queryParameters: {'tipo': 'CLIENTE', 'page': 0, 'size': 20}))
        .thenThrow(DioException.connectionError(requestOptions: RequestOptions(path: '/conversas'), reason: 'offline'));
    await expectLater(ChatRepository(dio: dio).listarConversasPessoas(), throwsA(isA<Exception>()));
  });
}
