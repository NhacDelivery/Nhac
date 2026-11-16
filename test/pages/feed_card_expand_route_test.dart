import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/pages/feed_post_detail_page.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class _AuthMock extends Mock implements AuthService {}

class _FeedAdapter implements HttpClientAdapter {
  final post = <String, dynamic>{
    'id': 'p100',
    'usuarioId': 'u100',
    'nomeUsuario': 'Usuario Hero',
    'conteudo': 'Conteudo do post animado',
    'hashTags': ['#Animacao'],
    'curtidas': 10,
    'comentarios': 2,
    'curtido': false,
    'salvo': false,
    'criadoEm': '2026-10-06T12:30:00Z',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final Object body;
    if (path == '/produtos/categorias') {
      body = ['Lanches'];
    } else if (path.contains('/comentarios')) {
      body = {'content': <dynamic>[]};
    } else if (path.endsWith('/p100')) {
      body = post;
    } else {
      body = {'content': [post]};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1\n');
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('Hero tags e transição do card ao abrir FeedPostDetailPage', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, null);
    });

    await mockNetworkImagesFor(() async {
      final auth = _AuthMock();
      when(() => auth.usuarioId).thenReturn('u100');
      when(() => auth.isAuthenticated).thenReturn(true);

      final dio = ApiClient().dio;
      final previousAdapter = dio.httpClientAdapter;
      dio.httpClientAdapter = _FeedAdapter();

      addTearDown(() {
        dio.httpClientAdapter = previousAdapter;
      });

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testRouter = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(body: FeedPage()),
          ),
          GoRoute(
            path: '/feed-post',
            pageBuilder: (context, state) {
              final post = state.extra! as FeedPostModel;
              final rectParam = state.uri.queryParameters['rect'];
              Rect? cardRect;
              if (rectParam != null) {
                final parts = rectParam.split(',').map(double.tryParse).toList();
                if (parts.length == 4 && parts.every((p) => p != null)) {
                  cardRect = Rect.fromLTWH(
                    parts[0]!,
                    parts[1]!,
                    parts[2]!,
                    parts[3]!,
                  );
                }
              }
              return ChatCardExpandPage(
                key: state.pageKey,
                cardRect: cardRect,
                child: FeedPostDetailPage(
                  post: post,
                  heroTag: post.id,
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp.router(
              routerConfig: testRouter,
            ),
          ),
        ),
      );

      await frames(tester);

      // Verifica se o card do post p100 foi renderizado no feed com as tags Hero
      final avatarHero = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'feed-avatar-p100',
      );
      final nomeHero = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'feed-nome-p100',
      );
      final tempoHero = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'feed-tempo-p100',
      );

      expect(avatarHero, findsOneWidget);
      expect(nomeHero, findsOneWidget);
      expect(tempoHero, findsOneWidget);

      // Clica no card para disparar a animação de expansão
      await tester.tap(find.text('Conteudo do post animado'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Confirma que abriu a tela de detalhes
      expect(find.byType(FeedPostDetailPage), findsOneWidget);

      // Confirma que os Heroes existem na tela
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == 'feed-avatar-p100',
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == 'feed-nome-p100',
        ),
        findsWidgets,
      );
    });
  });

  testWidgets('ChatCardExpandPage desativa animação da tela de trás e tem opaque false', (tester) async {
    const page = ChatCardExpandPage(
      key: ValueKey('test-expand'),
      child: SizedBox(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final route = page.createRoute(context) as PageRoute;
            expect(route.opaque, isFalse);
            expect(route.canTransitionFrom(MaterialPageRoute(builder: (_) => const SizedBox())), isFalse);
            expect(route.canTransitionTo(MaterialPageRoute(builder: (_) => const SizedBox())), isFalse);
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
