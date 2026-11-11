import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  String? step,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  } while (DateTime.now().isBefore(deadline));

  final widgetTypes = tester.allWidgets
      .take(30)
      .map((widget) => widget.runtimeType)
      .join(', ');
  final statuses = tester.allWidgets.whereType<Semantics>().where(
    (widget) => widget.key == const Key('e2e.tracking.status'),
  ).map((widget) => widget.properties.value).toList();
  throw TestFailure(
    'Timeout na etapa "${step ?? 'aguardar widget'}". '
    'Finder: $finder. Último estado: ${tester.binding.renderViews.length} '
    'render view(s); ciclo de vida: ${tester.binding.lifecycleState}; '
    'status renderizados: $statuses; primeiros widgets: [$widgetTypes].',
  );
}
