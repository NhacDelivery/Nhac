import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/profile/profile_publications_section.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/repositories/feed_repository.dart';

class _FeedRepositoryMock extends Mock implements FeedRepository {}

FeedPostModel _post(String id, String content) => FeedPostModel(
      id: id,
      nomeUsuario: 'Autor',
      usuarioId: 'user-1',
      conteudo: content,
      curtidas: 0,
      comentarios: 0,
    );

Future<void> _mount(
  WidgetTester tester,
  _FeedRepositoryMock repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfilePublicationsSection(
              usuarioId: 'user-1',
              repository: repository,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('exibe a grade quando a API retorna publicações', (tester) async {
    final repository = _FeedRepositoryMock();
    when(() => repository.buscarMinhasPublicacoes(page: 0))
        .thenAnswer((_) async => [_post('post-1', 'Almoço de hoje')]);

    await _mount(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Publicações'), findsOneWidget);
    expect(find.text('Almoço de hoje'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('estado vazio convida a publicar sem inventar conteúdo',
      (tester) async {
    final repository = _FeedRepositoryMock();
    when(() => repository.buscarMinhasPublicacoes(page: 0))
        .thenAnswer((_) async => []);

    await _mount(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Suas publicações aparecerão aqui.'), findsOneWidget);
    expect(find.text('Compartilhar experiência'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('paginação carrega a próxima página sem duplicar itens',
      (tester) async {
    final repository = _FeedRepositoryMock();
    when(() => repository.buscarMinhasPublicacoes(page: 0)).thenAnswer(
      (_) async => List.generate(
        20,
        (index) => _post('post-$index', 'Publicação $index'),
      ),
    );
    when(() => repository.buscarMinhasPublicacoes(page: 1))
        .thenAnswer((_) async => [
              _post('post-19', 'Publicação duplicada'),
              _post('post-20', 'Vigésima primeira'),
            ]);

    await _mount(tester, repository);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Carregar mais'));
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();

    expect(find.text('Vigésima primeira'), findsOneWidget);
    expect(find.text('Publicação duplicada'), findsNothing);
    verify(() => repository.buscarMinhasPublicacoes(page: 1)).called(1);
  });

  testWidgets('falha inicial oferece retry e não apresenta vazio falso',
      (tester) async {
    final repository = _FeedRepositoryMock();
    var attempts = 0;
    when(() => repository.buscarMinhasPublicacoes(page: 0)).thenAnswer(
      (_) async {
        attempts++;
        if (attempts == 1) throw Exception('offline');
        return [_post('post-1', 'Publicação recuperada')];
      },
    );

    await _mount(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar suas publicações.'), findsOneWidget);
    expect(find.text('Suas publicações aparecerão aqui.'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Publicação recuperada'), findsOneWidget);
  });
}
