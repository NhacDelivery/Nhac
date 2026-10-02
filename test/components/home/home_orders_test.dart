import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/home/home_orders.dart';
import 'package:nhac/components/home/home_order_tracking_card.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrdersRepositoryMock extends Mock implements PedidoRepository {}

class AuthMock extends Mock implements AuthService {}

class ConnectivityMock extends Mock implements ConnectivityService {}

class OrderSocketMock extends Mock implements PedidoStatusSocketService {}

void main() {
  late OrdersRepositoryMock repository;
  late AuthMock auth;
  late ConnectivityMock connectivity;
  late Map<String, OrderSocketMock> sockets;
  late Map<String, StreamController<StatusPedido>> updates;
  late GlobalKey<HomeOrdersState> key;
  PedidoModel order(String id, String status) => PedidoModel.fromMap({
        'id': id,
        'usuarioId': 'u1',
        'lojaId': 'l1',
        'lojaNome': 'Loja $id',
        'valorTotal': 20,
        'taxaFrete': 5,
        'formaPagamento': 'DINHEIRO',
        'status': status,
        'itens': [],
        'enderecoEntrega': {
          'rua': 'Rua',
          'numero': '1',
          'cidade': 'São Paulo',
          'estado': 'SP',
          'cep': '01000000',
          'bairro': 'Centro'
        },
      });
  setUpAll(
      () => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = OrdersRepositoryMock();
    auth = AuthMock();
    connectivity = ConnectivityMock();
    key = GlobalKey<HomeOrdersState>();
    sockets = {};
    updates = {};
    when(() => auth.usuarioId).thenReturn('u1');
    when(() => connectivity.isOnline).thenReturn(true);
    for (final id in ['p1', 'p2']) {
      final socket = OrderSocketMock();
      sockets[id] = socket;
      final stream = StreamController<StatusPedido>.broadcast();
      updates[id] = stream;
      when(() => socket.status).thenAnswer((_) => stream.stream);
      when(() => socket.conectado).thenAnswer((_) => const Stream.empty());
      when(() => socket.conectar(any())).thenAnswer((_) async {});
      when(() => socket.desconectar()).thenAnswer((_) async {});
      when(() => repository.buscarPedidoPorId(id))
          .thenAnswer((_) async => order(id, 'PREPARANDO'));
    }
  });
  tearDown(() async {
    for (final stream in updates.values) {
      await stream.close();
    }
  });
  Widget page({bool active = true}) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<ConnectivityService>.value(
                value: connectivity),
          ],
          child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (context, _) => MaterialApp(
                  home: Scaffold(
                      body: SingleChildScrollView(
                          child: HomeOrders(
                              key: key,
                              isActive: active,
                              repository: repository,
                              socketFactory: (id) => sockets[id]!))))));
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
      'descoberta inicial e resposta vazia não exibem cartão nem loading',
      (tester) async {
    final response = Completer<List<PedidoModel>>();
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) => response.future);
    await tester.pumpWidget(page());
    await flush(tester);
    expect(find.text('Seu pedido'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    response.complete([]);
    await flush(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'lista antiga não desfaz atualização individual recebida pelo socket',
      (tester) async {
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) async => [order('p1', 'PAGO'), order('p2', 'PAGO')]);
    await tester.pumpWidget(page());
    await flush(tester);
    final response = Completer<List<PedidoModel>>();
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) => response.future);
    final operation = key.currentState!.refresh();
    updates['p1']!.add(StatusPedido.preparando);
    await flush(tester);
    response.complete([order('p1', 'PAGO'), order('p2', 'PAGO')]);
    await operation;
    await flush(tester);
    final cards = tester
        .widgetList<HomeOrderTrackingCard>(find.byType(HomeOrderTrackingCard))
        .toList();
    expect(cards.first.initialPedido!.status, StatusPedido.preparando);
    expect(cards.last.initialPedido!.status, StatusPedido.pago);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'duas compras aparecem; socket atualiza somente o pedido correspondente',
      (tester) async {
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) async => [order('p1', 'PAGO'), order('p2', 'PAGO')]);
    await tester.pumpWidget(page());
    await flush(tester);
    expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    updates['p1']!.add(StatusPedido.preparando);
    await flush(tester);
    verify(() => repository.buscarPedidoPorId('p1')).called(1);
    verifyNever(() => repository.buscarPedidoPorId('p2'));
    verify(() => repository.invalidarPedido('p1')).called(1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'refresh conhecido mantém cartões; falha preserva dados; vazio remove',
      (tester) async {
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) async => [order('p1', 'PAGO')]);
    await tester.pumpWidget(page());
    await flush(tester);
    final response = Completer<List<PedidoModel>>();
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) => response.future);
    final operation = key.currentState!.refresh();
    await tester.pump();
    expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.completeError(Exception('Servidor indisponível'));
    await operation;
    await tester.pump();
    expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    expect(find.text('Não foi possível atualizar os pedidos.'), findsOneWidget);
    when(() => repository.buscarPedidosAtivos()).thenAnswer((_) async => []);
    await key.currentState!.refresh();
    await tester.pump();
    expect(find.byKey(const ValueKey('p1')), findsNothing);
    expect(find.text('Não foi possível atualizar os pedidos.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'resposta depois do dispose é descartada; aba inativa não faz polling',
      (tester) async {
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) async => [order('p1', 'PAGO')]);
    await tester.pumpWidget(page());
    await flush(tester);
    clearInteractions(repository);
    await tester.pumpWidget(page(active: false));
    await tester.pump(const Duration(minutes: 2));
    verifyNever(() => repository.buscarPedidosAtivos());
    verifyNever(() => repository.buscarPedidoPorId(any()));
    await tester.pumpWidget(const SizedBox());
    final lateResponse = Completer<List<PedidoModel>>();
    when(() => repository.buscarPedidosAtivos())
        .thenAnswer((_) => lateResponse.future);
    await tester.pumpWidget(page());
    await flush(tester);
    await tester.pumpWidget(const SizedBox());
    lateResponse.complete([order('p2', 'PAGO')]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
