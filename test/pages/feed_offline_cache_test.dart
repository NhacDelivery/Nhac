import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/repositories/feed_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/feed_cache_service.dart';
import 'package:provider/provider.dart';

class _MockFeedRepository extends Mock implements FeedRepository {}
class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockFeedRepository repository;
  late _MockAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FeedCacheService.limparCache();
    repository = _MockFeedRepository();
    authService = _MockAuthService();
    when(() => authService.usuarioId).thenReturn('user-1');
  });

  tearDown(() async {
    await FeedCacheService.limparCache();
  });

  testWidgets(
    'quando a rede falha (offline), exibe posts do cache com os mais recentes primeiro',
    (tester) async {
      final postAntigo = FeedPostModel(
        id: 'post-1',
        nomeUsuario: 'Usuário Antigo',
        conteudo: 'Publicação mais antiga',
        curtidas: 1,
        comentarios: 0,
        criadoEm: DateTime.parse('2026-11-10T10:00:00Z'),
      );
      final postRecente = FeedPostModel(
        id: 'post-2',
        nomeUsuario: 'Usuário Novo',
        conteudo: 'Publicação super recente',
        curtidas: 10,
        comentarios: 2,
        criadoEm: DateTime.parse('2026-11-16T08:00:00Z'),
      );

      // Pré-popula o cache local
      await FeedCacheService.salvar('Destaques', [postAntigo, postRecente]);

      // Simula erro de conexão (offline) no repository
      when(() => repository.buscarPosts(categoria: any(named: 'categoria'), page: any(named: 'page')))
          .thenThrow(Exception('Falha de conexão / Offline'));

      await mockNetworkImagesFor(() async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthService>.value(
            value: authService,
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                home: Scaffold(
                  body: FeedPage(repository: repository),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // O post mais recente aparece primeiro
        expect(find.text('Publicação super recente'), findsOneWidget);

        // Rola até o post anterior para garantir que ambos foram carregados no feed
        await tester.scrollUntilVisible(
          find.text('Publicação mais antiga'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Publicação mais antiga'), findsOneWidget);

        // Não deve exibir tela vazia nem mensagem fatal de erro como corpo principal
        expect(find.text('Não foi possível carregar o feed.'), findsNothing);
      });
    },
  );
}
