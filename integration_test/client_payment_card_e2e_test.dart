import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/main.dart' as app;
import 'package:nhac/pages/pagamento_pendente_page.dart';
import 'package:nhac/services/api_client.dart';

import 'support/e2e_actions.dart';
import 'support/e2e_backend.dart';
import 'support/e2e_checkout.dart';
import 'support/e2e_config.dart';
import 'support/e2e_finders.dart';
import 'support/e2e_recovery.dart';
import 'support/e2e_wait.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Cartão: falha recuperável, webhook e confirmação idempotente',
    (tester) async {
      await E2EConfig.validate();
      await app.main();
      await loginAsFixtureUser(tester);
      // Habilita a escolha no checkout, sem inicializar ou abrir a SDK externa.
      // Esta chave é fictícia e exclusiva do teste; PaymentSheet não é coberto.
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] =
          'pk_test_e2e_mock_exclusive_do_not_use';
      final merchant = await fixtureActor('e2e.lojista@nhac.local');
      addTearDown(() => merchant.close(force: true));
      await openFixtureCheckout(tester);
      await tapE2E(
        tester,
        find.byKey(E2EKeys.checkoutCard),
        step: 'selecionar cartão',
      );
      await tapE2E(
        tester,
        E2EFinders.checkoutConfirm,
        step: 'criar pedido cartão',
      );
      await waitFor(
        tester,
        find.text('Pagar com cartão'),
        step: 'abrir pagamento',
      );
      final id = tester
          .widget<PagamentoPendentePage>(find.byType(PagamentoPendentePage))
          .pedidoId;
      final before = (await ApiClient().dio.get<Map<String, dynamic>>(
        '/pedidos/$id/pagamento',
      )).data!;
      expect(before['clientSecret'], isNotEmpty);
      await expectSingleOrderAndStock(id, merchant);

      await stripeEvent(id, 'payment_intent.succeeded', invalid: true);
      expect((await clientOrder(id))['status'], 'PENDENTE');
      await stripeEvent(id, 'payment_intent.payment_failed');
      expect((await clientOrder(id))['status'], 'PENDENTE');
      await resumeFromHistory(tester, id);
      await waitFor(
        tester,
        find.text('Pagar com cartão'),
        step: 'oferecer nova tentativa no mesmo pedido',
      );
      final after = (await ApiClient().dio.get<Map<String, dynamic>>(
        '/pedidos/$id/pagamento',
      )).data!;
      expect(after['pedidoId'], id);
      expect(after['clientSecret'], before['clientSecret']);
      expect(after['expiraEm'], before['expiraEm']);
      await expectSingleOrderAndStock(id, merchant);

      await tapE2E(
        tester,
        find.text('Acompanhar pedido'),
        step: 'voltar ao rastreio',
      );
      await waitFor(
        tester,
        trackingStatus('PENDENTE'),
        timeout: const Duration(seconds: 45),
        step: 'aguardar confirmação',
      );
      await stripeEvent(id, 'payment_intent.succeeded');
      await waitFor(
        tester,
        trackingStatus('PAGO'),
        timeout: const Duration(seconds: 45),
        step: 'receber confirmação real',
      );
      await stripeEvent(id, 'payment_intent.succeeded');
      await stripeEvent(id, 'payment_intent.payment_failed');
      expect((await clientOrder(id))['status'], 'PAGO');
      // Reabrir uma cobrança já paga deve recuperar a nota, sem novo checkout.
      appRouter.go('/pagamento?pedidoId=$id');
      await finishReceipt(tester, id);
      await expectSingleOrderAndStock(id, merchant);
    },
    skip: !E2EConfig.runE2E,
  );
}
