import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/chat/conversa_pessoa_resumo.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/pages/lojas_favoritas_page.dart';
import 'package:nhac/repositories/loja_repository.dart';

class _Lojas extends Mock implements LojaRepository {}

void main() {
  test('foto do interlocutor sobrevive ao cache e à atualização do resumo', () {
    final pessoa = ConversaPessoaResumo.fromMap({
      'interlocutor': {
        'id': 'u',
        'nome': 'Ana',
        'imagemUrl': 'https://example.org/ana.jpg',
      },
    });
    final salva = ConversaPessoaResumo.fromMap(
      pessoa.copyWith(mensagensNaoLidas: 2).toMap(),
    );
    expect(salva.pessoaFotoUrl, 'https://example.org/ana.jpg');
    expect(
      ConversaPessoaResumo.fromMap({'pessoaNome': 'Ana'}).pessoaFotoUrl,
      isNull,
    );
  });

  testWidgets(
    'favoritas mostram os detalhes disponíveis e aceitam lojas sem foto',
    (tester) async {
      final repositorio = _Lojas();
      when(() => repositorio.listarLojasFavoritas(page: 0)).thenAnswer(
        (_) async => [
          LojasModel.fromMap({
            'id': '1',
            'nome': 'Cantina da Ana',
            'categoria': 'Massas',
            'dadosOperacionais': {
              'tempoEntregaMin': 25,
              'tempoEntregaMax': 40,
              'avaliacaoMedia': 4.8,
              'totalAvaliacoes': 3,
            },
          }),
          LojasModel(id: '2', nome: 'Café do Centro', categoria: ''),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: LojasFavoritasPage(repository: repositorio)),
      );
      await tester.pumpAndSettle();
      for (final texto in [
        'Cantina da Ana',
        'Massas',
        '25–40 min',
        '4,8',
        'Café do Centro',
      ]) {
        expect(find.text(texto), findsOneWidget);
      }
      expect(find.byIcon(Icons.storefront_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    },
  );
}
