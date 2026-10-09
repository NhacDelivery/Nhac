import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/rastreio_pedido_page.dart';
import 'package:nhac/repositories/entrega_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/notificacao_historico_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPedidoRepository extends Mock implements PedidoRepository {}

class MockLojaRepository extends Mock implements LojaRepository {}

class MockEntregaRepository extends Mock implements EntregaRepository {}

class MockSocket extends Mock implements PedidoStatusSocketService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.feentzs.nhac/live_notification');
  for (final status in [StatusPedido.entregue, StatusPedido.cancelado]) {
    testWidgets(
        'Pedido ${status.apiValue} já visto abre resumo sem mapa ou nova notificação',
        (tester) async {
      dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.marcarPedidoEntregueVisto('finalizado');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final pedidos = MockPedidoRepository();
      final lojas = MockLojaRepository();
      final entregas = MockEntregaRepository();
      final socket = MockSocket();
      when(() => socket.conectado).thenAnswer((_) => const Stream.empty());
      when(() => socket.status).thenAnswer((_) => const Stream.empty());
      when(() => socket.conectar(any())).thenAnswer((_) async {});
      when(() => socket.desconectar()).thenAnswer((_) async {});
      when(() => pedidos.buscarPedidoPorId('finalizado'))
          .thenAnswer((_) async => PedidoModel(
                id: 'finalizado',
                usuarioId: 'u1',
                lojaId: 'l1',
                lojaNome: 'Nhac Burguer',
                valorTotal: 20,
                taxaFrete: 0,
                formaPagamento: 'DINHEIRO',
                itens: const [],
                status: status,
                enderecoEntrega: EnderecoModel(
                    id: 'e1',
                    rua: 'Rua A',
                    numero: '1',
                    bairro: 'Centro',
                    cidade: 'São Paulo',
                    estado: 'SP',
                    cep: '01000000',
                    isPadrao: true),
              ));
      final router = GoRouter(initialLocation: '/rastreio', routes: [
        GoRoute(
            path: '/rastreio',
            builder: (_, __) => RastreioPedidoPage(
                pedidoId: 'finalizado',
                pedidoRepository: pedidos,
                lojaRepository: lojas,
                entregaRepository: entregas,
                statusSocket: socket)),
        GoRoute(
            path: '/pedido-detalhes',
            builder: (_, state) => Scaffold(
                body: Text('Resumo ${state.uri.queryParameters['pedidoId']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('Resumo finalizado'), findsOneWidget);
      verifyNever(() => entregas.buscarRota(any()));
      verifyNever(() => entregas.buscarLocalizacaoEntregador(any()));
      expect(calls.where((call) => call.method == 'showLiveNotification'),
          isEmpty);
      expect(calls.where((call) => call.method == 'updateLiveNotification'),
          isEmpty);
      expect(calls.single.method, 'cancelLiveNotification');
      expect(calls.single.arguments, {'pedidoId': 'finalizado'});
      expect(await NotificacaoHistoricoService.listar('u1'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
