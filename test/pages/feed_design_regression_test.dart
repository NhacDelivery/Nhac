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
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/pages/feed_post_detail_page.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class _Auth extends Mock implements AuthService {}

class _Adapter implements HttpClientAdapter {
  final post = <String, dynamic>{
    'id': 'p1',
    'usuarioId': 'u1',
    'nomeUsuario': 'Autora da publicação',
    'conteudo': List.filled(100, 'Uma publicação longa com várias linhas de texto.').join('\n'),
    'hashTags': ['#Nhac'],
    'curtidas': 1234,
    'comentarios': 0,
    'curtido': true,
    'salvo': true,
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final Object body;
    if (options.path.endsWith('/comentarios')) {
      body = {'content': []};
    } else if (options.path == '/feed/posts/p1') {
      body = post;
    } else {
      expect(options.path, anyOf('/feed/posts', '/feed/posts/salvos'));
      body = {'content': [post]};
    }
    return ResponseBody.fromString(jsonEncode(body), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
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
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp.router(routerConfig: router),
      ),
    ));
    await frames(tester);
  }

  testWidgets('publicação longa abre, volta e reabre sem overflow na transição', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: FeedPage())),
      GoRoute(path: '/feed-post', pageBuilder: (_, state) => CustomTransitionPage(
        transitionDuration: const Duration(milliseconds: 400),
        child: FeedPostDetailPage(post: state.extra! as FeedPostModel),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      )),
    ]);
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
  });

  testWidgets('publicações salvas não exibem o carrossel de banners', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: FeedPage(salvos: true))),
    ]);
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
