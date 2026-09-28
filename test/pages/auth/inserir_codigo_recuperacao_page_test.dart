import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/pages/auth/recuperacao_senha/inserir_codigo_recuperacao_page.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService auth;
  late GoRouter router;

  setUp(() {
    auth = MockAuthService();
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const InserirCodigoRecuperacaoPage(
          metodo: 'email',
          contato: 'cliente@exemplo.com',
        ),
      ),
      GoRoute(
        path: '/recuperacao/nova-senha',
        builder: (_, state) => Scaffold(
          body: Text('Nova senha: ${(state.extra as Map)['codigo']}'),
        ),
      ),
    ]);
  });

  tearDown(() => router.dispose());

  Future<void> abrirPagina(WidgetTester tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    ));
    await tester.pump();
  }

  testWidgets('código incorreto permanece na tela e permite uma nova tentativa',
      (tester) async {
    when(() => auth.validarCodigoRecuperacaoEmail(any(), any()))
        .thenAnswer((_) async => throw Exception('Código inválido'));
    await abrirPagina(tester);
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    expect(find.text('Código inválido'), findsOneWidget);
    expect(find.textContaining('Nova senha:'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '1');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('só avança depois da confirmação do servidor', (tester) async {
    final resposta = Completer<void>();
    when(() => auth.validarCodigoRecuperacaoEmail(any(), any()))
        .thenAnswer((_) => resposta.future);
    await abrirPagina(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.textContaining('Nova senha:'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    resposta.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nova senha: 123456'), findsOneWidget);
    verify(() => auth.validarCodigoRecuperacaoEmail(
        'cliente@exemplo.com', '123456')).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('resposta após sair da tela não usa controlador descartado',
      (tester) async {
    final resposta = Completer<void>();
    when(() => auth.validarCodigoRecuperacaoEmail(any(), any()))
        .thenAnswer((_) => resposta.future);
    await abrirPagina(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump(const Duration(milliseconds: 500));
    verify(() => auth.validarCodigoRecuperacaoEmail(any(), any())).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    resposta.completeError(Exception('Código inválido'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
