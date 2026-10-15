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
}
