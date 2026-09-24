import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhac/main.dart' as app;

import 'support/e2e_actions.dart';
import 'support/e2e_config.dart';
import 'support/e2e_finders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E-001 Login autentica o cliente fixture e abre a home', (
    tester,
  ) async {
    await E2EConfig.validate();
    await app.main();

    await loginAsFixtureUser(tester);

    expect(E2EFinders.homeReady, findsOneWidget);
  }, skip: !E2EConfig.runE2E);
}
