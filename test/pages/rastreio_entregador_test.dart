import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/pages/rastreio_pedido_page.dart';
import 'package:nhac/repositories/entrega_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';

class MockPedidoRepository extends Mock implements PedidoRepository {}

class MockLojaRepository extends Mock implements LojaRepository {}

class MockEntregaRepository extends Mock implements EntregaRepository {}

class MockPedidoStatusSocketService extends Mock
    implements PedidoStatusSocketService {}

void main() {
  late MockPedidoRepository mockPedidoRepository;
  late MockLojaRepository mockLojaRepository;
  late MockEntregaRepository mockEntregaRepository;
  late MockPedidoStatusSocketService mockSocket;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
  });

  setUp(() {
    mockPedidoRepository = MockPedidoRepository();
    mockLojaRepository = MockLojaRepository();
    mockEntregaRepository = MockEntregaRepository();
    mockSocket = MockPedidoStatusSocketService();

    when(() => mockSocket.conectado).thenAnswer((_) => const Stream.empty());
    when(() => mockSocket.status).thenAnswer((_) => const Stream.empty());
    when(() => mockSocket.conectar(any())).thenAnswer((_) async {});
    when(() => mockSocket.dispose()).thenReturn(null);

    final loja = LojasModel(
      id: 'loja1',
      nome: 'Pizzaria Top',
      categoria: 'Pizzaria',
      imagemUrl: '',
    );
    when(() => mockLojaRepository.buscarLoja(any()))
        .thenAnswer((_) async => loja);
    when(() => mockEntregaRepository.buscarRota(any()))
        .thenThrow(Exception('sem rota'));
    when(() => mockEntregaRepository.buscarLocalizacaoEntregador(any()))
        .thenAnswer((_) async => null);
  });

  final endereco = EnderecoModel(
    id: 'end1',
    rua: 'Rua das Flores',
    numero: '123',
    bairro: 'Centro',
    cidade: 'São Paulo',
    estado: 'SP',
    cep: '01000-000',
    isPadrao: true,
  );

  PedidoModel criarPedido({
    required StatusPedido status,
    String? codigoEntrega,
    EntregadorPedidoModel? entregador,
  }) {
    return PedidoModel(
      id: 'ped-100',
      usuarioId: 'user1',
      lojaId: 'loja1',
      lojaNome: 'Pizzaria Top',
      valorTotal: 50.0,
      taxaFrete: 5.0,
      formaPagamento: 'PIX',
      enderecoEntrega: endereco,
      itens: const [],
      status: status,
      codigoEntrega: codigoEntrega,
      entregador: entregador,
    );
  }

  Widget createWidgetUnderTest(String pedidoId) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        home: RastreioPedidoPage(
          pedidoId: pedidoId,
          pedidoRepository: mockPedidoRepository,
          lojaRepository: mockLojaRepository,
          entregaRepository: mockEntregaRepository,
          statusSocket: mockSocket,
        ),
      ),
    );
  }

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('F3 - Nome do motoboy ao aceitar no rastreio', () {
    const entregador = EntregadorPedidoModel(
      nome: 'Carlos S.',
      fotoUrl: null,
      tipoVeiculo: 'MOTO',
      modeloVeiculo: 'CG 160',
      corVeiculo: 'Preta',
      placaVeiculo: 'ABC1D23',
      avaliacaoMedia: 4.8,
      totalAvaliacoes: 12,
    );

    testWidgets(
        'Preparando com entregador: exibe aceitou sua entrega e dados do entregador',
        (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        status: StatusPedido.preparando,
        entregador: entregador,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-100'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest('ped-100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carlos S. aceitou sua entrega'), findsOneWidget);
      expect(
          find.byKey(const Key('cartao-entregador-rastreio')), findsOneWidget);
      expect(find.text('Carlos S.'), findsOneWidget);
      expect(find.textContaining('CG 160'), findsOneWidget);
      expect(find.textContaining('ABC1D23'), findsOneWidget);
      expect(find.text('4.8 (12)'), findsOneWidget);
    });

    testWidgets('Saiu para entrega com entregador: exibe está a caminho',
        (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        status: StatusPedido.saiuEntrega,
        codigoEntrega: '1234',
        entregador: entregador,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-100'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest('ped-100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carlos S. está a caminho'), findsOneWidget);
      expect(
          find.byKey(const Key('cartao-entregador-rastreio')), findsOneWidget);
    });

    testWidgets(
        'Sem entregador: mantém status padrão e não exibe cartão de entregador',
        (tester) async {
      setupScreen(tester);
      final pedido = criarPedido(
        status: StatusPedido.preparando,
        entregador: null,
      );
      when(() => mockPedidoRepository.buscarPedidoPorId('ped-100'))
          .thenAnswer((_) async => pedido);

      await tester.pumpWidget(createWidgetUnderTest('ped-100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carlos S. aceitou sua entrega'), findsNothing);
      expect(find.text('Em preparo'), findsOneWidget);
      expect(find.byKey(const Key('cartao-entregador-rastreio')), findsNothing);
    });
  });
}
