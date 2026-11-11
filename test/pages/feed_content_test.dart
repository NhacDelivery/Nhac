import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/components/feed_content.dart';
import 'package:nhac/models/feed/feed_post_model.dart';

void main() {
  testWidgets(
    'hashtags do campo específico aparecem mesmo sem estar no texto',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedContent(
              conteudo: 'Meu almoço',
              tags: ['#Nhac', '#Bom', '#Nhac'],
            ),
          ),
        ),
      );
      expect(find.text('Meu almoço'), findsOneWidget);
      expect(find.text('#Nhac'), findsOneWidget);
      expect(find.text('#Bom'), findsOneWidget);
    },
  );

  test('comentário destacado e permissão vêm do servidor', () {
    final post = FeedPostModel.fromMap({
      'id': 'p',
      'nomeUsuario': 'Autor',
      'usuarioId': 'u',
      'conteudo': 'Post',
      'curtidas': 1,
      'comentarios': 2,
      'podeEditar': true,
      'topComment': {'nomeUsuario': 'Comentador', 'conteudo': 'Primeiro'},
    });
    expect(post.usuarioId, 'u');
    expect(post.podeEditar, isTrue);
    expect(post.topComment!.conteudo, 'Primeiro');
  });

  testWidgets('texto longo exibe botão Ler mais e permite expandir e recolher',
      (tester) async {
    const textoLongo =
        'Linha 1: Primeira linha do almoço saboroso.\n'
        'Linha 2: Segunda linha cheia de detalhes sobre o prato.\n'
        'Linha 3: Terceira linha com acompanhamentos e bebidas.\n'
        'Linha 4: Quarta linha que ultrapassa o limite padrão.\n'
        'Linha 5: Quinta linha com a sobremesa deliciosa.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: FeedContent(
              conteudo: textoLongo,
              tags: ['#Nhac'],
            ),
          ),
        ),
      ),
    );

    // Inicialmente mostra 'Ler mais'
    expect(find.text('Ler mais'), findsOneWidget);
    expect(find.text('Ler menos'), findsNothing);

    // Toca em 'Ler mais'
    await tester.tap(find.text('Ler mais'));
    await tester.pumpAndSettle();

    // Agora exibe 'Ler menos'
    expect(find.text('Ler menos'), findsOneWidget);
    expect(find.text('Ler mais'), findsNothing);

    // Toca em 'Ler menos'
    await tester.tap(find.text('Ler menos'));
    await tester.pumpAndSettle();

    // Volta a exibir 'Ler mais'
    expect(find.text('Ler mais'), findsOneWidget);
    expect(find.text('Ler menos'), findsNothing);
  });
}
