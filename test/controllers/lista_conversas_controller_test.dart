import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/controllers/lista_conversas_controller.dart';
import 'package:nhac/globals/exceptions.dart';

void main() {
  test('falha inicial é erro, não uma caixa vazia confirmada', () async {
    final caixa = ListaConversasController<String>(
        buscar: (_, __) async => throw NetworkException('Sem conexão.'),
        identificar: (s) => s);
    await caixa.carregar();
    expect(caixa.carregou, isFalse);
    expect(caixa.erro, 'Sem conexão.');
    caixa.dispose();
  });

  test('paginação conserva itens, deduplica e repete a página que falhou',
      () async {
    final paginas = <int>[];
    bool falhar = true;
    final caixa = ListaConversasController<String>(
        tamanho: 2,
        identificar: (s) => s,
        buscar: (p, _) async {
          paginas.add(p);
          if (p == 0) return ['a', 'b'];
          if (falhar) throw NetworkException('Sem conexão.');
          return ['b', 'c'];
        });
    await caixa.carregar();
    await caixa.carregar();
    expect(caixa.itens, ['a', 'b']);
    falhar = false;
    await caixa.tentarNovamente();
    expect(caixa.itens, ['a', 'b', 'c']);
    expect(paginas, [0, 1, 1]);
    caixa.dispose();
  });

  test('refresh falho preserva a caixa e retry volta à primeira página',
      () async {
    final paginas = <int>[];
    bool falhar = false;
    final caixa = ListaConversasController<String>(
        tamanho: 1,
        identificar: (s) => s,
        buscar: (p, _) async {
          paginas.add(p);
          if (falhar) throw NetworkException('Sem conexão.');
          return ['conversa-$p'];
        });
    await caixa.carregar();
    await caixa.carregar();
    falhar = true;
    await caixa.carregar(reiniciar: true);
    expect(caixa.itens, ['conversa-0', 'conversa-1']);
    falhar = false;
    await caixa.tentarNovamente();
    expect(paginas, [0, 1, 0, 0]);
    expect(caixa.itens, ['conversa-0']);
    caixa.dispose();
  });

  test('consultas simultâneas compartilham a chamada pendente', () async {
    final resposta = Completer<List<String>>();
    var chamadas = 0;
    final caixa = ListaConversasController<String>(
        identificar: (s) => s,
        buscar: (_, __) {
          chamadas++;
          return resposta.future;
        });
    final primeira = caixa.carregar();
    final segunda = caixa.carregar();
    resposta.complete(['conversa']);
    await Future.wait([primeira, segunda]);
    expect(chamadas, 1);
    expect(caixa.carregando, isFalse);
    caixa.dispose();
  });

  test('resposta após sair da tela não notifica nem restaura dados', () async {
    final resposta = Completer<List<String>>();
    final caixa = ListaConversasController<String>(
        identificar: (s) => s, buscar: (_, __) => resposta.future);
    final consulta = caixa.carregar();
    caixa.dispose();
    resposta.complete(['conversa']);
    await consulta;
    expect(caixa.itens, isEmpty);
  });
}
