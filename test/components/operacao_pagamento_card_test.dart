import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/pedido/operacao_pagamento_card.dart';
import 'package:nhac/globals/themes.dart';
import 'package:nhac/models/pedido/operacao_pagamento_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class RepoMock extends Mock implements PedidoRepository {}

void main() {
  late RepoMock repo;
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
  });
  setUp(() {
    repo = RepoMock();
  });
  Widget app({Future<void> Function()? aoCancelar}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
          theme: lightTheme,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: OperacaoPagamentoCard(
                          pedidoId: 'pedido',
                          repository: repo,
                          aoCancelar: aoCancelar))))));
  const elegivel =
      OperacaoPagamentoModel(estado: 'REGULAR', podeSolicitarEstorno: true);
  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.tap(find.text('Cancelar e solicitar estorno'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmar(WidgetTester tester) async {
    await tester
        .tap(find.widgetWithText(FilledButton, 'Cancelar e solicitar estorno'));
    await tester.pumpAndSettle();
  }

  Future<void> sair(WidgetTester tester) async =>
      tester.pumpWidget(const SizedBox());

  testWidgets('erro é legível em cartão estreito com texto ampliado', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    when(() => repo.buscarOperacaoPagamento('pedido')).thenThrow(Exception('offline'));
    await tester.pumpWidget(ScreenUtilInit(designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: Center(child: SizedBox(width: 240, child: OperacaoPagamentoCard(
          pedidoId: 'pedido', repository: repo))))))));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar o pagamento.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await sair(tester);
  });

  testWidgets('conciliação não permite novo pagamento ou estorno',
      (tester) async {
    when(() => repo.buscarOperacaoPagamento('pedido')).thenAnswer(
        (_) async => const OperacaoPagamentoModel(estado: 'CONCILIACAO'));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Pagamento em conferência'), findsOneWidget);
    expect(find.textContaining('Não pague novamente'), findsOneWidget);
    expect(find.text('Cancelar e solicitar estorno'), findsNothing);
    await sair(tester);
  });
  testWidgets('cancelar confirmação preserva pedido sem POST', (tester) async {
    when(() => repo.buscarOperacaoPagamento('pedido'))
        .thenAnswer((_) async => elegivel);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await abrirDialogo(tester);
    await tester.tap(find.text('Manter pedido'));
    await tester.pumpAndSettle();
    verifyNever(() => repo.solicitarEstorno(any()));
    await sair(tester);
  });
  testWidgets('confirma uma vez e mostra solicitação sem afirmar devolução',
      (tester) async {
    var solicitado = false;
    var callbacks = 0;
    when(() => repo.buscarOperacaoPagamento('pedido')).thenAnswer((_) async =>
        solicitado
            ? const OperacaoPagamentoModel(estado: 'ESTORNO_SOLICITADO')
            : elegivel);
    when(() => repo.solicitarEstorno('pedido')).thenAnswer((_) async {
      solicitado = true;
    });
    await tester.pumpWidget(app(aoCancelar: () async {
      callbacks++;
    }));
    await tester.pumpAndSettle();
    await abrirDialogo(tester);
    await confirmar(tester);
    verify(() => repo.solicitarEstorno('pedido')).called(1);
    expect(callbacks, 1);
    expect(find.text('Estorno solicitado'), findsOneWidget);
    expect(find.text('Estorno concluído'), findsNothing);
    await sair(tester);
  });
  testWidgets(
      'timeout exige consulta antes de nova solicitação e retry não repete POST',
      (tester) async {
    var consultar = 0;
    when(() => repo.buscarOperacaoPagamento('pedido')).thenAnswer((_) async {
      consultar++;
      return consultar == 1
          ? elegivel
          : const OperacaoPagamentoModel(estado: 'ESTORNO_PROCESSANDO');
    });
    when(() => repo.solicitarEstorno('pedido')).thenThrow(Exception('timeout'));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await abrirDialogo(tester);
    await confirmar(tester);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    await tester.tap(find.text('Atualizar pagamento'));
    await tester.pumpAndSettle();
    expect(find.text('Estorno em andamento'), findsOneWidget);
    verify(() => repo.solicitarEstorno('pedido')).called(1);
    await sair(tester);
  });
  testWidgets('falha de refresh conserva estado e mostra erro com retry',
      (tester) async {
    var falhar = false;
    when(() => repo.buscarOperacaoPagamento('pedido')).thenAnswer((_) async {
      if (falhar) throw Exception('offline');
      return const OperacaoPagamentoModel(estado: 'ESTORNO_REVISAO');
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    falhar = true;
    await tester.tap(find.text('Atualizar pagamento'));
    await tester.pumpAndSettle();
    expect(find.text('Estorno em análise'), findsOneWidget);
    expect(
        find.text('Não foi possível atualizar o pagamento.'), findsOneWidget);
    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar o pagamento.'), findsNothing);
    await sair(tester);
  });
  testWidgets('conclusão integral fica legível em celular com texto ampliado',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    when(() => repo.buscarOperacaoPagamento('pedido')).thenAnswer(
        (_) async => const OperacaoPagamentoModel(estado: 'ESTORNO_CONCLUIDO'));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Estorno concluído'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/estorno-concluido.png'));
    }
    await sair(tester);
  });
  testWidgets('dispose durante consulta ignora resposta e encerra timer',
      (tester) async {
    final pending = Completer<OperacaoPagamentoModel>();
    when(() => repo.buscarOperacaoPagamento('pedido'))
        .thenAnswer((_) => pending.future);
    await tester.pumpWidget(app());
    await sair(tester);
    pending.complete(elegivel);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
