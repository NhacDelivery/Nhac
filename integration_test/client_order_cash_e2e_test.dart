import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/main.dart' as app;
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:provider/provider.dart';

import 'support/e2e_actions.dart';
import 'support/e2e_config.dart';
import 'support/e2e_checkout.dart';
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

      await openFixtureCheckout(tester);
      await tapE2E(
        tester,
        E2EFinders.checkoutCash,
        step: 'selecionar dinheiro',
      );

      await tapE2E(
        tester,
        E2EFinders.checkoutConfirm,
        step: 'confirmar pedido',
      );
      await tester.tap(E2EFinders.checkoutConfirm, warnIfMissed: false);

      await waitFor(
        tester,
        E2EFinders.checkoutSuccess,
        step: 'confirmar exatamente um pedido',
      );
      final successOrderId = semanticsValue(
        tester,
        E2EFinders.checkoutSuccessOrderId,
      );
      expect(successOrderId, isNotNull);
      expect(successOrderId, isNotEmpty);

      await tester.tap(E2EFinders.checkoutSuccessContinue);
      await waitFor(tester, E2EFinders.trackingRoot, step: 'abrir rastreio');
      final trackingOrderId = semanticsValue(
        tester,
        E2EFinders.trackingOrderId,
      );
      expect(trackingOrderId, successOrderId);
      await waitFor(
        tester,
        E2EFinders.trackingStatus,
        step: 'renderizar status inicial do backend',
      );
      expect(semanticsValue(tester, E2EFinders.trackingStatus), 'PENDENTE');

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
