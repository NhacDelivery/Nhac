import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/components/home/home_orders_carousel.dart';

void main() {
  Widget page(List<String> ids, {double width = 320}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: HomeOrdersCarousel(
            orderIds: ids,
            children: [for (final id in ids) SizedBox(
              height: id == 'p2' ? 520 : 200,
              child: Center(child: Text('Cartão $id')),
            )],
          ),
        ),
      ),
    ),
  );

  testWidgets('navega por setas e gesto sem empilhar ou recortar cartões', (tester) async {
    await tester.pumpWidget(page(['p1', 'p2', 'p3']));
    await tester.pump();
    expect(find.text('Pedido 1 de 3'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Cartão p2')).dx, greaterThan(320));
    await tester.tap(find.byTooltip('Próximo pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido 2 de 3'), findsOneWidget);
    expect(tester.getCenter(find.text('Cartão p2')).dx, closeTo(160, 1));
    expect(tester.getSize(find.byType(SingleChildScrollView).last).height, 520);
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(-270, 0));
    await tester.pumpAndSettle();
    expect(find.text('Pedido 3 de 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserva pedido selecionado na reordenação e ajusta remoção e largura', (tester) async {
    await tester.pumpWidget(page(['p1', 'p2', 'p3']));
    await tester.pump();
    await tester.tap(find.byTooltip('Próximo pedido'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(['p2', 'p1', 'p3']));
    await tester.pumpAndSettle();
    expect(find.text('Pedido 1 de 3'), findsOneWidget);
    expect(tester.getCenter(find.text('Cartão p2')).dx, closeTo(160, 1));
    await tester.pumpWidget(page(['p2', 'p1', 'p3'], width: 390));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Cartão p2')).dx, closeTo(195, 1));
    await tester.pumpWidget(page(['p1']));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Próximo pedido'), findsNothing);
    expect(tester.getCenter(find.text('Cartão p1')).dx, closeTo(160, 1));
    expect(tester.takeException(), isNull);
  });
}
