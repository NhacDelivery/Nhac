import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:nhac/components/home/home_banner_carousel.dart';
import 'package:nhac/components/feed_timestamp.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/pages/feed_post_detail_page.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class _Auth extends Mock implements AuthService {}

class _Adapter implements HttpClientAdapter {
  final bool withComments;
  Map<String, dynamic>? enviado;
  String? chave;
  _Adapter({this.withComments = false});
  final comentario = <String, dynamic>{
    'id': 'c1',
    'usuarioId': 'u2',
    'nomeUsuario': 'Outra pessoa com um nome muito longo',
    'conteudo': 'Pergunta da publicação',
    'isAuthor': false,
    'criadoEm': '2026-10-06T12:34:00Z',
    'curtidas': 0,
    'curtido': false,
  };
  final post = <String, dynamic>{
    'id': 'p1',
    'usuarioId': 'u1',
    'nomeUsuario': 'Autora da publicação',
    'conteudo': List.filled(
      100,
      'Uma publicação longa com várias linhas de texto.',
    ).join('\n'),
    'hashTags': ['#Nhac'],
    'curtidas': 1234,
    'comentarios': 0,
    'curtido': true,
    'salvo': true,
    'criadoEm': '2026-10-06T12:30:00Z',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body;
    if (options.path == '/produtos/categorias') {
      body = ['Lanches'];
    } else if (options.path.endsWith('/comentarios/c1/curtida')) {
      comentario['curtido'] = options.method == 'PUT';
      comentario['curtidas'] = options.method == 'PUT' ? 1 : 0;
      body = comentario;
    } else if (options.path.endsWith('/comentarios') &&
        options.method == 'POST') {
      enviado = Map<String, dynamic>.from(options.data as Map);
      chave = options.headers['Idempotency-Key'] as String?;
      body = {
        ...comentario,
        'id': 'c2',
        'conteudo': enviado!['conteudo'],
        'respostaAId': enviado!['respostaAId'],
        'respostaANome': comentario['nomeUsuario'],
      };
    } else if (options.path.endsWith('/comentarios')) {
      body = {
        'content': withComments ? [comentario] : [],
      };
    } else if (options.path == '/feed/posts/p1') {
      body = post;
    } else {
      expect(options.path, anyOf('/feed/posts', '/feed/posts/salvos'));
      body = {
        'content': [post],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late HttpClientAdapter oldAdapter;
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080/api/v1');
    auth = _Auth();
    when(() => auth.usuarioId).thenReturn('u1');
    oldAdapter = ApiClient().dio.httpClientAdapter;
    ApiClient().dio.httpClientAdapter = _Adapter();
    ApiClient().atualizarTokenCache('test-token');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
  });
  tearDown(() {
    ApiClient().dio.httpClientAdapter = oldAdapter;
    ApiClient().atualizarTokenCache(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
  }

  Future<void> mount(WidgetTester tester, GoRouter router) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await frames(tester);
  }

  testWidgets(
    'publicação longa abre, volta e reabre sem overflow na transição',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: FeedPage()),
          ),
          GoRoute(
            path: '/feed-post',
            pageBuilder: (_, state) => CustomTransitionPage(
              transitionDuration: const Duration(milliseconds: 400),
              child: FeedPostDetailPage(post: state.extra! as FeedPostModel),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await mockNetworkImagesFor(() async {
        await mount(tester, router);
        final like = tester.widget<Icon>(find.byIcon(Icons.thumb_up_alt));
        expect(like.color, const Color(0xFFFF6961));
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(find.text('Autora da publicação'));
          await tester.tap(find.text('Autora da publicação'));
          await frames(tester);
          expect(find.byType(FeedPostDetailPage), findsOneWidget);
          router.pop();
          await frames(tester);
          expect(find.byType(FeedPage), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
      });
    },
  );

  testWidgets('datas, curtir e responder comentários usam o servidor', (
    tester,
  ) async {
    final adapter = _Adapter(withComments: true);
    adapter.post['conteudo'] = 'Publicação curta';
    ApiClient().dio.httpClientAdapter = adapter;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              FeedPostDetailPage(post: FeedPostModel.fromMap(adapter.post)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await mockNetworkImagesFor(() async {
      await mount(tester, router);
      expect(find.byType(FeedTimestamp), findsNWidgets(2));
      expect(find.textContaining('12:3'), findsNWidgets(2));
      await tester.ensureVisible(find.byIcon(Icons.favorite_border));
      await tester.tap(find.byIcon(Icons.favorite_border));
      await frames(tester);
      expect(adapter.comentario['curtido'], isTrue);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite));
      await frames(tester);
      expect(adapter.comentario['curtidas'], 0);
      await tester.tap(find.text('Responder'));
      await frames(tester);
      expect(find.textContaining('Respondendo a'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Minha resposta');
      await tester.tap(find.byTooltip('Enviar comentário'));
      await frames(tester);
      expect(adapter.enviado, {
        'conteudo': 'Minha resposta',
        'respostaAId': 'c1',
      });
      expect(adapter.chave, isNotEmpty);
      expect(find.textContaining('Respondendo a'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
    });
  });

  testWidgets('publicações salvas não exibem o carrossel de banners', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: FeedPage(salvos: true)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await mockNetworkImagesFor(() async {
      await mount(tester, router);
      expect(find.text('Publicações salvas'), findsOneWidget);
      expect(find.byType(HomeBannerCarousel), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
    });
  });
}
