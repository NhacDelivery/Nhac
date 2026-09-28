import 'package:flutter_test/flutter_test.dart';

import 'e2e_finders.dart';
import 'e2e_wait.dart';

Future<void> tapE2E(
  WidgetTester tester,
  Finder finder, {
  required String step,
}) async {
  await waitFor(tester, finder, step: step);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  // Uma rota em transição mantém widgets visíveis na árvore enquanto o
  // Navigator ainda bloqueia seus toques. Aguarde o alvo receber hit test.
  await waitFor(tester, finder.hitTestable(), step: '$step (tocável)');
  await tester.tap(finder.hitTestable());
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> loginAsFixtureUser(WidgetTester tester) async {
  await waitFor(tester, E2EFinders.welcomeContinue, step: 'exibir boas-vindas');
  await tapE2E(
    tester,
    E2EFinders.welcomeContinue,
    step: 'continuar das boas-vindas',
  );

  await waitFor(tester, E2EFinders.loginEmail, step: 'abrir login por e-mail');
  await tester.enterText(E2EFinders.loginEmail, 'e2e.cliente@nhac.local');
  await tapE2E(tester, E2EFinders.loginSubmit, step: 'continuar para senha');

  await waitFor(tester, E2EFinders.loginPassword, step: 'abrir senha');
  await tester.enterText(E2EFinders.loginPassword, 'NhacE2E#123');
  await tapE2E(tester, E2EFinders.loginSubmit, step: 'enviar login');

  await waitFor(tester, E2EFinders.homeReady, step: 'autenticar e abrir home');
}
