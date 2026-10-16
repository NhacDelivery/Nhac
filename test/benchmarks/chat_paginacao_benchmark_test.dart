import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/repositories/chat_repository.dart';

class CatalogoConversas extends HttpClientAdapter {
  int consultas = 0;
  int bytes = 0;
  final dados = [for (var i = 0; i < 520; i++) {
    'id': 'conversa-$i', 'tipo': i < 400 ? 'LOJA' : 'CLIENTE',
    'interlocutor': {'id': 'destino-$i', 'nome': 'Contato $i'},
    'ultimaMensagemPreview': 'Mensagem sintética', 'naoLidas': 0,
  }];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    consultas++;
    final tipo = options.queryParameters['tipo'];
    final todos = tipo == null ? dados : dados.where((c) => c['tipo'] == tipo).toList();
    final pagina = options.queryParameters['page'] as int;
    final tamanho = options.queryParameters['size'] as int;
    final content = todos.skip(pagina * tamanho).take(tamanho).toList();
    final json = jsonEncode({'content': content, 'last': (pagina + 1) * tamanho >= todos.length});
    bytes += utf8.encode(json).length;
    return ResponseBody.fromString(json, 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

// Algoritmo da revisão-base 0307b90, somente para comparação controlada.
Future<List<String>> paginaLegada(Dio dio, int pagina, int tamanho) async {
  final itens = <Map>[];
  var origem = 0;
  while (itens.length < (pagina + 1) * tamanho) {
    final resposta = await dio.get('/conversas', queryParameters: {'page': origem++, 'size': 100});
    final dados = resposta.data as Map;
    final conteudo = dados['content'] as List;
    itens.addAll(conteudo.cast<Map>().where((c) => c['tipo'] == 'CLIENTE'));
    if (dados['last'] == true || conteudo.isEmpty) break;
  }
  return itens.skip(pagina * tamanho).take(tamanho).map((c) => c['id'] as String).toList();
}
void main() {
  test('mesmos 20 resultados na página 5, sem varrer 400 conversas de lojas', () async {
    final antes = CatalogoConversas(); final depois = CatalogoConversas();
    final dioAntes = Dio()..httpClientAdapter = antes;
    final dioDepois = Dio()..httpClientAdapter = depois;
    final esperado = await paginaLegada(dioAntes, 5, 20);
    final atual = await ChatRepository(dio: dioDepois).listarConversasPessoas(pagina: 5);
    expect(atual.map((c) => c.id).toList(), esperado);
    expect(antes.consultas, 6); expect(depois.consultas, 1);
    expect(depois.bytes, lessThan(antes.bytes));
    print('CHAT_BENCHMARK ${jsonEncode({'fixture': '400 lojas + 120 pessoas; página 5, tamanho 20',
      'baseline_requests': antes.consultas, 'filtered_requests': depois.consultas,
      'baseline_bytes': antes.bytes, 'filtered_bytes': depois.bytes,
      'note': 'HTTP simulado: contagem e payload, não latência de rede'})}');
    dioAntes.close(); dioDepois.close();
  });
}
