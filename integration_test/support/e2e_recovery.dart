import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/globals/router.dart';

import 'e2e_actions.dart';
import 'e2e_checkout.dart';
import 'e2e_finders.dart';
import 'e2e_wait.dart';

Finder trackingStatus(String status) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.key == const Key('e2e.tracking.status') &&
      widget.properties.value == status,
);

/// Desmonta a tela de pagamento e reabre pelo histórico e rastreio reais.
/// Não simula encerramento do processo Android nem indisponibilidade de rede.
Future<void> resumeFromHistory(WidgetTester tester, String id) async {
  appRouter.go('/meus-pedidos');
  await tapE2E(
    tester,
    find.byKey(ValueKey('pedido-$id')),
    step: 'reabrir pedido existente pelo histórico',
  );
  await waitFor(
    tester,
    E2EFinders.trackingOrderId,
    step: 'recuperar rastreio do pedido',
  );
  expect(semanticsValue(tester, E2EFinders.trackingOrderId), id);
  await waitFor(
    tester,
    trackingStatus('PENDENTE'),
    timeout: const Duration(seconds: 45),
    step: 'pedido segue pendente',
  );
  await tapE2E(
    tester,
    find.text('Continuar pagamento'),
    step: 'retomar cobrança existente',
  );
}

Future<void> finishReceipt(WidgetTester tester, String id) async {
  await waitFor(
    tester,
    E2EFinders.checkoutSuccess,
    step: 'confirmar pagamento na nota fiscal',
  );
  expect(semanticsValue(tester, E2EFinders.checkoutSuccessOrderId), id);
  await tapE2E(
    tester,
    E2EFinders.checkoutSuccessContinue,
    step: 'acompanhar pedido pago',
  );
  await waitFor(
    tester,
    trackingStatus('PAGO'),
    timeout: const Duration(seconds: 45),
    step: 'renderizar confirmação',
  );
  expect(semanticsValue(tester, E2EFinders.trackingOrderId), id);
  expect(find.text('Continuar pagamento'), findsNothing);
}
