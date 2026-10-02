import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/nota_fiscal_pedido.dart';
import 'package:nhac/models/pedido/item_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PedidoRepositoryMock extends Mock implements PedidoRepository {}

PedidoModel pedido({double total = 53, double frete = 5}) => PedidoModel(
      id: 'abcd1234-ffff',
      usuarioId: 'u1',
      lojaId: 'loja',
      lojaNome: 'Pizzaria Top',
      valorTotal: total,
      taxaFrete: frete,
      formaPagamento: 'PIX',
      enderecoEntrega: EnderecoModel(
        id: 'e1',
        rua: 'Rua A',
        numero: '1',
        bairro: 'Centro',
        cidade: 'São Paulo',
        estado: 'SP',
        cep: '01000-000',
        isPadrao: true,
      ),
      itens: const [
        ItemPedidoModel(
          id: 'i1',
          produtoId: 'p1',
          nome: 'Pizza',
          imagemUrl: '',
          preco: 24,
          quantidade: 2,
        ),
      ],
      status: StatusPedido.pago,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('NotaFiscalDados.fromPedido', () {
    test('calcula o desconto a partir de itens + frete - total', () {
      // itens 48 + frete 5 - total 43 = desconto 10
      final dados = NotaFiscalDados.fromPedido(pedido(total: 43));
      expect(dados.subtotal, 48);
      expect(dados.desconto, closeTo(10, 0.001));
      expect(dados.total, 43);
    });

    test('sem cupom (ou diferença negativa) o desconto fica zero', () {
      expect(NotaFiscalDados.fromPedido(pedido(total: 53)).desconto, 0);
      expect(NotaFiscalDados.fromPedido(pedido(total: 60)).desconto, 0);
    });
  });

  group('mostrarNotaFiscalEVerPedido', () {
    late PedidoRepositoryMock repository;
    late List<String> destinos;
    var concluiu = 0;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = PedidoRepositoryMock();
      destinos = [];
      concluiu = 0;
    });

    Widget app(Future<void> Function(BuildContext) acao) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => acao(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/rastreio',
            builder: (_, state) {
              destinos.add(state.uri.toString());
              return const Scaffold(body: Text('rastreio'));
            },
          ),
        ],
      );
      return ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp.router(routerConfig: router),
      );
    }

    void preparar(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> chamar(WidgetTester tester) async {
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('mostra a nota e só abre o pedido depois de "Ver pedido"',
        (tester) async {
      when(() => repository.buscarPedidoPorId('abcd1234-ffff'))
          .thenAnswer((_) async => pedido(total: 43));
      preparar(tester);
      await tester.pumpWidget(app((c) => mostrarNotaFiscalEVerPedido(
            c,
            pedidoId: 'abcd1234-ffff',
            repository: repository,
            aoConcluir: () => concluiu++,
          )));
      await chamar(tester);
      expect(find.text('Pizzaria Top'), findsOneWidget);
      expect(find.text('Desconto do cupom'), findsOneWidget);
      expect(find.text('Ver pedido'), findsOneWidget);
      expect(concluiu, 0);
      expect(destinos, isEmpty);

      await tester.tap(find.text('Ver pedido'));
      await tester.pumpAndSettle();
      expect(concluiu, 1);
      expect(destinos, ['/rastreio?pedidoId=abcd1234-ffff']);
    });

    testWidgets('na segunda vez vai direto ao pedido, sem repetir a nota',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'nota_fiscal_exibida_abcd1234-ffff': true});
      preparar(tester);
      await tester.pumpWidget(app((c) => mostrarNotaFiscalEVerPedido(
            c,
            pedidoId: 'abcd1234-ffff',
            repository: repository,
            aoConcluir: () => concluiu++,
          )));
      await chamar(tester);
      await tester.pumpAndSettle();
      expect(find.text('Ver pedido'), findsNothing);
      expect(concluiu, 1);
      expect(destinos, ['/rastreio?pedidoId=abcd1234-ffff']);
    });

    testWidgets('API fora do ar usa o snapshot local', (tester) async {
      when(() => repository.buscarPedidoPorId(any()))
          .thenAnswer((_) async => throw Exception('offline'));
      final local = NotaFiscalDados(
        pedidoId: 'abcd1234-ffff',
        lojaNome: '',
        data: DateTime(2026, 10, 2, 12),
        itens: const [NotaFiscalItem(nome: 'Pizza', preco: 24, quantidade: 2)],
        taxaFrete: 5,
        desconto: 0,
        total: 53,
      );
      preparar(tester);
      await tester.pumpWidget(app((c) => mostrarNotaFiscalEVerPedido(
            c,
            pedidoId: 'abcd1234-ffff',
            dadosLocais: local,
            repository: repository,
          )));
      await chamar(tester);
      expect(find.text('Nhac Delivery'), findsOneWidget);
      expect(find.text('Ver pedido'), findsOneWidget);
    });

    testWidgets('sem API e sem snapshot nunca bloqueia: abre o pedido',
        (tester) async {
      when(() => repository.buscarPedidoPorId(any()))
          .thenAnswer((_) async => throw Exception('offline'));
      preparar(tester);
      await tester.pumpWidget(app((c) => mostrarNotaFiscalEVerPedido(
            c,
            pedidoId: 'abcd1234-ffff',
            repository: repository,
            aoConcluir: () => concluiu++,
          )));
      await chamar(tester);
      await tester.pumpAndSettle();
      expect(concluiu, 1);
      expect(destinos, ['/rastreio?pedidoId=abcd1234-ffff']);
    });
  });
}
