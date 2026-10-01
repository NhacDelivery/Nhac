import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/pedido/pedido_resumo_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/pages/meus_pedidos_page.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class MockPedidoRepository extends Mock implements PedidoRepository {}

void main() {
  for (final status in [StatusPedido.entregue, StatusPedido.cancelado, StatusPedido.preparando]) {
    testWidgets('Pedido ${status.apiValue} abre a tela correta', (tester) async {
      final repository = MockPedidoRepository();
      when(() => repository.buscarHistorico(page: 0, size: 20)).thenAnswer((_) async => [
        PedidoResumoModel(id: 'pedido/1', lojaId: 'l1', lojaNome: 'Nhac Burguer', valorTotal: 32.5, status: status),
      ]);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => MeusPedidosPage(repository: repository)),
        GoRoute(path: '/pedido-detalhes', builder: (_, state) => Scaffold(body: Text('Resumo ${state.uri.queryParameters['pedidoId']}'))),
        GoRoute(path: '/rastreio', builder: (_, __) => const Scaffold(body: Text('Mapa'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.textContaining('32,50'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pedido-pedido/1')));
      await tester.pumpAndSettle();
      expect(find.text(status.terminal ? 'Resumo pedido/1' : 'Mapa'), findsOneWidget);
      expect(find.text(status.terminal ? 'Mapa' : 'Resumo pedido/1'), findsNothing);
    });
  }

  testWidgets('Falha ao atualizar preserva os pedidos anteriores', (tester) async {
    final repository = MockPedidoRepository();
    var chamadas = 0;
    when(() => repository.buscarHistorico(page: 0, size: 20)).thenAnswer((_) async {
      if (++chamadas > 1) throw Exception('offline');
      return [const PedidoResumoModel(id: 'p1', lojaId: 'l1', lojaNome: 'Nhac Burguer', valorTotal: 32.5, status: StatusPedido.entregue)];
    });
    await tester.pumpWidget(MaterialApp(home: MeusPedidosPage(repository: repository)));
    await tester.pumpAndSettle();
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Nhac Burguer'), findsOneWidget);
    expect(find.text('Não foi possível carregar seus pedidos.'), findsOneWidget);
  });
}
