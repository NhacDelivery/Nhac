import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_publish_page.dart';
import 'package:nhac/repositories/feed_repository.dart';

class MockPublisher extends Mock implements FeedRepository {}

void main() {
  late MockPublisher repository;
  setUp(() { repository = MockPublisher(); });

  Future<void> abrir(WidgetTester tester) async {
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (context, _) => Scaffold(body: Column(children: [const Text('Feed atualizado'), TextButton(onPressed: () => context.push('/publicar'), child: const Text('Criar'))]))),
      GoRoute(path: '/publicar', builder: (_, __) => FeedPublishPage(repository: repository)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
  }

  Future<void> publicar(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('feed.publish.submit')), 250,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed.publish.submit')));
    await tester.pump();
  }

  testWidgets('conteúdo vazio não chega ao servidor', (tester) async {
    await abrir(tester);
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Escreva algo para publicar.'), findsOneWidget);
    verifyNever(() => repository.criarPost(conteudo: any(named: 'conteudo'),
      imagens: any(named: 'imagens'), hashTags: any(named: 'hashTags'), lojaId: any(named: 'lojaId')));
  });

  testWidgets('erro preserva texto e permite tentar novamente', (tester) async {
    when(() => repository.criarPost(conteudo: any(named: 'conteudo'),
      imagens: any(named: 'imagens'), hashTags: any(named: 'hashTags'), lojaId: any(named: 'lojaId')))
        .thenThrow(Exception('offline'));
    await abrir(tester);
    await tester.enterText(find.byKey(const Key('feed.publish.conteudo')), 'Minha experiência');
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Seu conteúdo foi preservado'), findsOneWidget);
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(find.byKey(const Key('feed.publish.conteudo')));
    expect(field.controller!.text, 'Minha experiência');
    await tester.scrollUntilVisible(find.byKey(const Key('feed.publish.submit')), 250,
      scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(find.byKey(const Key('feed.publish.submit'))).onPressed, isNotNull);
  });

  testWidgets('bloqueia segundo envio enquanto o primeiro está pendente', (tester) async {
    final resposta = Completer<FeedPostModel>();
    when(() => repository.criarPost(conteudo: any(named: 'conteudo'),
      imagens: any(named: 'imagens'), hashTags: any(named: 'hashTags'), lojaId: any(named: 'lojaId')))
        .thenAnswer((_) => resposta.future);
    await abrir(tester);
    await tester.enterText(find.byKey(const Key('feed.publish.conteudo')), 'Pedido chegou');
    await publicar(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('feed.publish.submit'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('feed.publish.submit')));
    verify(() => repository.criarPost(conteudo: 'Pedido chegou', imagens: [], hashTags: [], lojaId: null)).called(1);
    resposta.completeError(Exception('offline'));
    await tester.pumpAndSettle();
  });

  testWidgets('sucesso retorna ao feed com o post confirmado', (tester) async {
    when(() => repository.criarPost(conteudo: any(named: 'conteudo'),
      imagens: any(named: 'imagens'), hashTags: any(named: 'hashTags'), lojaId: any(named: 'lojaId')))
        .thenAnswer((_) async => FeedPostModel.fromMap({
          'id': 'post-confirmado', 'nomeUsuario': 'Autor', 'conteudo': 'Pedido chegou',
          'imagens': <String>[], 'hashTags': <String>[], 'curtidas': 0, 'comentarios': 0,
        }));
    await abrir(tester);
    await tester.enterText(find.byKey(const Key('feed.publish.conteudo')), 'Pedido chegou');
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Feed atualizado'), findsOneWidget);
    expect(find.text('Nova publicação'), findsNothing);
  });

  testWidgets('voltar protege a publicação ainda não enviada', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byKey(const Key('feed.publish.conteudo')), 'Rascunho');
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar publicação?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Rascunho'), findsOneWidget);
  });
}
