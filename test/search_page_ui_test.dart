import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/repositories/produto_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/pages/search_page.dart';

class MockProdutos extends Mock implements ProdutoRepository {}

class MockLojas extends Mock implements LojaRepository {}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> montar(
    WidgetTester tester,
    MockProdutos produtos,
    MockLojas lojas, {
    String? categoria,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: SearchPage(
            initialCategory: categoria,
            produtoRepository: produtos,
            lojaRepository: lojas,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  final produto = ProdutosModel(
    id: 'p1',
    nome: 'Suco natural',
    preco: 12,
    categoriaMenu: 'Bebidas',
    lojaId: 'l1',
  );

  testWidgets(
    'digitar pesquisa por nome mostra resultados em Tudo sem trocar o filtro',
    (tester) async {
      final produtos = MockProdutos();
      final lojas = MockLojas();
      when(
        () => produtos.buscarProdutosPorNome('suco'),
      ).thenAnswer((_) async => [produto]);
      when(() => lojas.buscarLojasPorNome('suco')).thenAnswer((_) async => []);
      await montar(tester, produtos, lojas);
      await tester.enterText(find.byType(TextField), 'suco');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Suco natural'), findsOneWidget);
      expect(find.text('Tudo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('categoria inicial mostra resultado assim que a busca termina', (
    tester,
  ) async {
    final produtos = MockProdutos();
    final lojas = MockLojas();
    when(
      () => produtos.buscarPorCategoria('Bebidas'),
    ).thenAnswer((_) async => [produto]);
    await montar(tester, produtos, lojas, categoria: 'Bebidas');
    expect(find.text('Suco natural'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'falha mostra nova tentativa e resposta antiga não substitui nova pesquisa',
    (tester) async {
      final produtos = MockProdutos();
      final lojas = MockLojas();
      final antiga = Completer<List<ProdutosModel>>();
      when(
        () => produtos.buscarProdutosPorNome('antiga'),
      ).thenAnswer((_) => antiga.future);
      when(() => lojas.buscarLojasPorNome(any())).thenAnswer((_) async => []);
      when(
        () => produtos.buscarProdutosPorNome('nova'),
      ).thenAnswer((_) async => [produto]);
      await montar(tester, produtos, lojas);
      await tester.enterText(find.byType(TextField), 'antiga');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'nova');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      antiga.completeError(Exception('Falha antiga'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Suco natural'), findsOneWidget);
      when(
        () => produtos.buscarProdutosPorNome('falha'),
      ).thenAnswer((_) async => throw Exception('Sem rede'));
      await tester.enterText(find.byType(TextField), 'falha');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Nada encontrado'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  setUpAll(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'),
  );
  testWidgets('SearchPage deve renderizar o campo de busca e aceitar input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return const MaterialApp(home: SearchPage());
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // SearchPage não usa AppBar: a barra de busca é custom (Row com botão
    // de voltar + campo de texto arredondado), ver _buildBarraBusca().
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump();

    // Verificar se o texto foi digitado
    expect(find.text('pizza'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'falha de lojas preserva produtos e tenta recuperar somente fonte pendente',
      (tester) async {
    final produtos = MockProdutos();
    final lojas = MockLojas();
    when(() => produtos.buscarProdutosPorNome('suco'))
        .thenAnswer((_) async => [produto]);
    when(() => lojas.buscarLojasPorNome('suco'))
        .thenThrow(Exception('offline'));
    await montar(tester, produtos, lojas);
    await tester.enterText(find.byType(TextField), 'suco');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Suco natural'), findsOneWidget);
    expect(find.text('Não foi possível carregar as lojas.'), findsOneWidget);
    when(() => lojas.buscarLojasPorNome('suco')).thenAnswer((_) async => []);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.text('Não foi possível carregar as lojas.'), findsNothing);
    verify(() => produtos.buscarProdutosPorNome('suco')).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('carregar mais busca página seguinte e não duplica produtos',
      (tester) async {
    final produtos = MockProdutos();
    final lojas = MockLojas();
    final primeira = List.generate(
        20,
        (i) => ProdutosModel(
            id: 'p$i', nome: 'Suco $i', preco: 12, categoriaMenu: 'Bebidas'));
    when(() => produtos.buscarProdutosPorNome('suco'))
        .thenAnswer((_) async => primeira);
    when(() => produtos.buscarProdutosPorNome('suco', page: 1))
        .thenAnswer((_) async => [
              primeira.last,
              ProdutosModel(
                  id: 'p20',
                  nome: 'Suco extra',
                  preco: 12,
                  categoriaMenu: 'Bebidas')
            ]);
    when(() => lojas.buscarLojasPorNome('suco')).thenAnswer((_) async => []);
    await montar(tester, produtos, lojas);
    await tester.enterText(find.byType(TextField), 'suco');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('Carregar mais resultados'), 600,
        scrollable: find
            .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Carregar mais resultados'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('Suco extra'), 600,
        scrollable: find
            .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Suco extra'), findsOneWidget);
    expect(find.text('Carregar mais resultados'), findsNothing);
    verify(() => produtos.buscarProdutosPorNome('suco', page: 1)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
