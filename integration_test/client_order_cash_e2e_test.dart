import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/main.dart' as app;
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:provider/provider.dart';

import 'support/e2e_actions.dart';
import 'support/e2e_config.dart';
import 'support/e2e_finders.dart';
import 'support/e2e_wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E-001..004 cliente cria pedido em dinheiro e abre o rastreio',
    (tester) async {
      await E2EConfig.validate();
      await app.main();
      await loginAsFixtureUser(tester);

      // A lista de restaurantes fica abaixo da primeira tela e o SliverList
      // só monta seus cards quando a rolagem chega até ela.
      await tester.scrollUntilVisible(
        E2EFinders.store,
        350,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView).first,
          matching: find.byType(Scrollable),
        ).first,
        maxScrolls: 20,
      );
      await tapE2E(tester, E2EFinders.store, step: 'abrir loja fixture');
      await waitFor(
        tester,
        E2EFinders.product,
        step: 'carregar produto fixture',
      );
      await tapE2E(tester, E2EFinders.product, step: 'abrir produto fixture');
      await waitFor(tester, E2EFinders.productAdd, step: 'abrir produto');
      await tapE2E(tester, E2EFinders.productAdd, step: 'adicionar produto');

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));

      await tapE2E(tester, E2EFinders.cartOpen, step: 'abrir carrinho');
      await waitFor(
        tester,
        E2EFinders.cartItem,
        step: 'exibir item no carrinho',
      );
      expect(E2EFinders.cartItem, findsOneWidget);
      expect(_semanticsValue(tester, E2EFinders.cartItemQuantity), '1');
      expect(
          _semanticsValue(tester, E2EFinders.cartStoreId), E2EConfig.storeId);

      await tapE2E(tester, E2EFinders.cartCheckout, step: 'abrir checkout');
      await waitFor(
        tester,
        E2EFinders.checkoutAddress,
        step: 'carregar checkout',
      );
      expect(E2EFinders.checkoutAddress, findsOneWidget);
      await waitFor(
        tester,
        E2EFinders.checkoutTotal,
        step: 'calcular total com frete',
      );
      expect(_semanticsValue(tester, E2EFinders.checkoutTotal), '30.00');
      await tapE2E(
        tester,
        E2EFinders.checkoutCash,
        step: 'selecionar dinheiro',
      );

      await waitFor(
        tester,
        E2EFinders.checkoutConfirm,
        step: 'habilitar confirmação',
      );
      await tester.tap(E2EFinders.checkoutConfirm, warnIfMissed: false);
      await tester.tap(E2EFinders.checkoutConfirm, warnIfMissed: false);

      await waitFor(
        tester,
        E2EFinders.checkoutSuccess,
        step: 'confirmar exatamente um pedido',
      );
      final successOrderId = _semanticsValue(
        tester,
        E2EFinders.checkoutSuccessOrderId,
      );
      expect(successOrderId, isNotNull);
      expect(successOrderId, isNotEmpty);

      await tester.tap(E2EFinders.checkoutSuccessContinue);
      await waitFor(tester, E2EFinders.trackingRoot, step: 'abrir rastreio');
      final trackingOrderId = _semanticsValue(
        tester,
        E2EFinders.trackingOrderId,
      );
      expect(trackingOrderId, successOrderId);
      await waitFor(
        tester,
        E2EFinders.trackingStatus,
        step: 'renderizar status inicial do backend',
      );
      expect(_semanticsValue(tester, E2EFinders.trackingStatus), 'PENDENTE');

      final trackingContext = tester.element(E2EFinders.trackingRoot);
      final cart = Provider.of<CartProvider>(trackingContext, listen: false);
      expect(cart.itens, isEmpty);

      final orders = await PedidoRepository().buscarHistorico(size: 10);
      expect(orders, hasLength(1));
      expect(orders.single.id, successOrderId);
      expect(
        find.textContaining('Erro ao carregar dados do pedido'),
        findsNothing,
      );
    },
    skip: !E2EConfig.runE2E,
  );
}

String? _semanticsValue(WidgetTester tester, Finder finder) =>
    tester.widget<Semantics>(finder).properties.value;
