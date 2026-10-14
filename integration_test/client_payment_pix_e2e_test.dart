import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/main.dart' as app;
import 'package:nhac/pages/qrcode_pix_page.dart';
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
    'PIX: reabrir a mesma cobrança e confirmar sem duplicar pedido',
    (tester) async {
      await E2EConfig.validate();
      await app.main();
      await loginAsFixtureUser(tester);
      final merchant = await fixtureActor('e2e.lojista@nhac.local');
      addTearDown(() => merchant.close(force: true));
      await openFixtureCheckout(tester);
      await tapE2E(
        tester,
        find.byKey(E2EKeys.checkoutPix),
        step: 'selecionar PIX',
      );
      await tester.enterText(find.byKey(E2EKeys.checkoutCpf), '52998224725');
      await tester.testTextInput.hide();
      await tapE2E(
        tester,
        E2EFinders.checkoutConfirm,
        step: 'criar pedido PIX',
      );
      await waitFor(tester, find.byType(QrCodePixPage), step: 'exibir QR Code');
      final before = tester.widget<QrCodePixPage>(find.byType(QrCodePixPage));
      final id = before.paymentId;
      expect(before.pixCopiaECola, isNotEmpty);
      expect(before.simulacaoDisponivel, isTrue);
      await expectSingleOrderAndStock(id, merchant);

      await resumeFromHistory(tester, id);
      await waitFor(
        tester,
        find.byType(QrCodePixPage),
        step: 'restaurar QR Code',
      );
      final after = tester.widget<QrCodePixPage>(find.byType(QrCodePixPage));
      expect(after.paymentId, id);
      expect(after.pixCopiaECola, before.pixCopiaECola);
      expect(after.expiraEm, before.expiraEm);
      expect(after.valor, 30);
      await expectSingleOrderAndStock(id, merchant);
      await tapE2E(
        tester,
        find.text('Simular pagamento (teste)'),
        step: 'confirmar PIX pelo recurso autorizado do perfil E2E',
      );
      await finishReceipt(tester, id);
      expect((await clientOrder(id))['status'], 'PAGO');
      await expectSingleOrderAndStock(id, merchant);
      final unavailable = await ApiClient().dio.get(
        '/pedidos/$id/pagamento',
        options: Options(validateStatus: (status) => status == 409),
      );
      expect(unavailable.statusCode, 409);
    },
    skip: !E2EConfig.runE2E,
  );
}
