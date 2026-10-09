import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nhac/services/auth_service.dart';

import 'dart:async';

import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/services/feed_tentativa_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_publish_page.dart';
import 'package:nhac/repositories/feed_repository.dart';

class MockPublisher extends Mock implements FeedRepository {}

class PublishAuth extends Fake implements AuthService {
  @override
  String? get usuarioId => 'feed-test-user';
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  late MockPublisher repository;
  setUp(() {
    repository = MockPublisher();
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
  });

  Future<void> abrir(WidgetTester tester, {FeedPostModel? post}) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('Feed atualizado'),
                TextButton(
                  onPressed: () => context.push('/publicar'),
                  child: const Text('Criar'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/publicar',
          builder: (_, __) =>
              FeedPublishPage(repository: repository, post: post),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: PublishAuth(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
  }

  Future<void> publicar(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('feed.publish.submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed.publish.submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('conteúdo vazio não chega ao servidor', (tester) async {
    await abrir(tester);
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Escreva algo para publicar.'), findsOneWidget);
    verifyNever(
      () => repository.criarPost(
        conteudo: any(named: 'conteudo'),
        imagens: any(named: 'imagens'),
        hashTags: any(named: 'hashTags'),
        lojaId: any(named: 'lojaId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  testWidgets('erro preserva texto e permite tentar novamente', (tester) async {
    when(
      () => repository.criarPost(
        conteudo: any(named: 'conteudo'),
        imagens: any(named: 'imagens'),
        hashTags: any(named: 'hashTags'),
        lojaId: any(named: 'lojaId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(Exception('offline'));
    await abrir(tester);
    await tester.enterText(
      find.byKey(const Key('feed.publish.conteudo')),
      'Minha experiência',
    );
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Seu conteúdo foi preservado'), findsOneWidget);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('feed.publish.conteudo')),
    );
    expect(field.controller!.text, 'Minha experiência');
    await tester.scrollUntilVisible(
      find.byKey(const Key('feed.publish.submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('feed.publish.submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('bloqueia segundo envio enquanto o primeiro está pendente', (
    tester,
  ) async {
    final resposta = Completer<FeedPostModel>();
    when(
      () => repository.criarPost(
        conteudo: any(named: 'conteudo'),
        imagens: any(named: 'imagens'),
        hashTags: any(named: 'hashTags'),
        lojaId: any(named: 'lojaId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) => resposta.future);
    await abrir(tester);
    await tester.enterText(
      find.byKey(const Key('feed.publish.conteudo')),
      'Pedido chegou',
    );
    await publicar(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('feed.publish.submit')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('feed.publish.submit')));
    verify(
      () => repository.criarPost(
        conteudo: 'Pedido chegou',
        imagens: [],
        hashTags: [],
        lojaId: null,
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
    resposta.completeError(Exception('offline'));
    await tester.pumpAndSettle();
  });

  testWidgets('sucesso retorna ao feed com o post confirmado', (tester) async {
    when(
      () => repository.criarPost(
        conteudo: any(named: 'conteudo'),
        imagens: any(named: 'imagens'),
        hashTags: any(named: 'hashTags'),
        lojaId: any(named: 'lojaId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => FeedPostModel.fromMap({
        'id': 'post-confirmado',
        'nomeUsuario': 'Autor',
        'conteudo': 'Pedido chegou',
        'imagens': <String>[],
        'hashTags': <String>[],
        'curtidas': 0,
        'comentarios': 0,
      }),
    );
    await abrir(tester);
    await tester.enterText(
      find.byKey(const Key('feed.publish.conteudo')),
      'Pedido chegou',
    );
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Feed atualizado'), findsOneWidget);
    expect(find.text('Nova publicação'), findsNothing);
  });

  testWidgets('voltar protege a publicação ainda não enviada', (tester) async {
    await abrir(tester);
    await tester.enterText(
      find.byKey(const Key('feed.publish.conteudo')),
      'Rascunho',
    );
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar publicação?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Rascunho'), findsOneWidget);
  });
  testWidgets('rejeição definitiva libera edição e cria uma tentativa nova', (
    tester,
  ) async {
    when(
      () => repository.criarPost(
        conteudo: any(named: 'conteudo'),
        imagens: any(named: 'imagens'),
        hashTags: any(named: 'hashTags'),
        lojaId: any(named: 'lojaId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(AppException('Texto inválido', statusCode: 422));
    await abrir(tester);
    await tester.enterText(
      find.byKey(const Key('feed.publish.conteudo')),
      'Texto rejeitado',
    );
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(
      await const FeedTentativaService().carregar('feed-test-user', 'post'),
      isNull,
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('feed.publish.conteudo')))
          .enabled,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('feed.publish.conteudo')),
      'Texto corrigido',
    );
    await publicar(tester);
    await tester.pumpAndSettle();
    final calls = verify(
      () => repository.criarPost(
        conteudo: captureAny(named: 'conteudo'),
        imagens: any(named: 'imagens'),
        hashTags: any(named: 'hashTags'),
        lojaId: any(named: 'lojaId'),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    expect(calls[0], 'Texto rejeitado');
    expect(calls[2], 'Texto corrigido');
    expect(calls[1], isNot(calls[3]));
  });
  testWidgets('edição incerta mantém chave e conteúdo após reabrir',
      (tester) async {
    final post = FeedPostModel.fromMap({
      'id': 'editado',
      'curtidas': 0,
      'comentarios': 0,
      'nomeUsuario': 'Autor',
      'conteudo': 'Original',
      'imagens': <String>[],
      'hashTags': <String>[]
    });
    final chaves = <String>[];
    when(() => repository.editar(post, any(), any(),
            imagens: any(named: 'imagens'),
            lojaId: any(named: 'lojaId'),
            alterarLoja: true,
            idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((invocation) async {
      chaves.add(invocation.namedArguments[#idempotencyKey] as String);
      throw Exception('Resposta perdida');
    });
    await abrir(tester, post: post);
    await tester.enterText(
        find.byKey(const Key('feed.publish.conteudo')), 'Conteúdo atualizado');
    await publicar(tester);
    await tester.pumpAndSettle();
    final tentativa = await const FeedTentativaService()
        .carregar('feed-test-user', 'editar:editado');
    expect(tentativa!['payload']['conteudo'], 'Conteúdo atualizado');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await abrir(tester, post: post);
    final campo = tester
        .widget<TextFormField>(find.byKey(const Key('feed.publish.conteudo')));
    expect(campo.controller!.text, 'Conteúdo atualizado');
    expect(campo.enabled, isFalse);
    await publicar(tester);
    await tester.pumpAndSettle();
    expect(chaves.length, 2);
    expect(chaves[0], chaves[1]);
  });
}
