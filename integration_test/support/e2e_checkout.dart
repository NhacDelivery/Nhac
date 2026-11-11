import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/e2e/e2e_keys.dart';

import 'e2e_actions.dart';
import 'e2e_config.dart';
import 'e2e_finders.dart';
import 'e2e_wait.dart';

/// Compra real pela UI; cada cenário começa com banco e aplicativo limpos.
Future<void> openFixtureCheckout(WidgetTester tester) async {
  // A lista de restaurantes fica abaixo da primeira tela e o SliverList
  // só monta seus cards quando a rolagem chega até ela.
  await tester.scrollUntilVisible(
    E2EFinders.store,
    350,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 20,
  );
  await tapE2E(tester, E2EFinders.store, step: 'abrir loja fixture');
  await waitFor(tester, E2EFinders.product, step: 'carregar produto fixture');
  await tapE2E(tester, E2EFinders.product, step: 'abrir produto fixture');
  await waitFor(tester, E2EFinders.productAdd, step: 'abrir produto');
  await tapE2E(tester, E2EFinders.productAdd, step: 'adicionar produto');

  // As duas telas são abertas por Navigator.push. O aviso de item
  // adicionado pode cobrir os botões de voltar durante a transição.
  Navigator.of(tester.element(E2EFinders.productAdd)).pop();
  await tester.pump(const Duration(milliseconds: 500));
  await waitFor(tester, E2EFinders.product, step: 'voltar para loja');
  Navigator.of(tester.element(E2EFinders.product)).pop();
  await tester.pump(const Duration(milliseconds: 500));
  if (E2EFinders.cartOpen.hitTestable().evaluate().isEmpty) {
    await tapE2E(
      tester,
      E2EFinders.homeScrollTop,
      step: 'expandir barra da home',
    );
    await tester.pump(const Duration(milliseconds: 800));
  }
  await waitFor(
    tester,
    E2EFinders.cartOpen.hitTestable(),
    step: 'voltar para home',
  );

  await tapE2E(tester, E2EFinders.cartOpen, step: 'abrir carrinho');
  await waitFor(tester, E2EFinders.cartItem, step: 'exibir item no carrinho');
  expect(E2EFinders.cartItem, findsOneWidget);
  expect(semanticsValue(tester, E2EFinders.cartItemQuantity), '1');
  expect(semanticsValue(tester, E2EFinders.cartStoreId), E2EConfig.storeId);

  await tapE2E(tester, E2EFinders.cartCheckout, step: 'abrir checkout');
  await waitFor(tester, E2EFinders.checkoutAddress, step: 'carregar checkout');
  expect(E2EFinders.checkoutAddress, findsOneWidget);
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.key == E2EKeys.checkoutTotal &&
          widget.properties.value == '30.00',
    ),
    step: 'calcular total com frete',
  );
  expect(semanticsValue(tester, E2EFinders.checkoutTotal), '30.00');
}

String? semanticsValue(WidgetTester tester, Finder finder) =>
    tester.widget<Semantics>(finder).properties.value;
