import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/pages/auth/cadastro/verificar_email_cadastro.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService auth;

  setUp(() {
    auth = MockAuthService();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> abrirPagina(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: const MaterialApp(
            home: VerificarEmailCadastro(email: 'cliente@exemplo.com'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('confirmação guarda prova e e-mail antes de avançar', (tester) async {
    when(() => auth.confirmarEmailCadastro(any(), any()))
        .thenAnswer((_) async => 'prova-do-email');
    final cadastro = CadastroController();
    final router = GoRouter(initialLocation: '/verificar', routes: [
      GoRoute(path: '/verificar', builder: (_, __) =>
          const VerificarEmailCadastro(email: 'cliente@exemplo.com')),
      GoRoute(path: '/cadastro/nome', builder: (_, __) =>
          const Scaffold(body: Text('Próxima etapa'))),
    ]);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<CadastroController>.value(value: cadastro),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    ));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(cadastro.email, 'cliente@exemplo.com');
    expect(cadastro.tokenCadastro, 'prova-do-email');
    expect(find.text('Próxima etapa'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    cadastro.dispose();
  });

  testWidgets('código inválido é limpo e permite digitar e apagar novamente',
      (tester) async {
    when(() => auth.confirmarEmailCadastro(any(), any()))
        .thenAnswer((_) async => throw Exception('Código incorreto'));
    await abrirPagina(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1');
    verify(() => auth.confirmarEmailCadastro('cliente@exemplo.com', '123456'))
        .called(1);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('sair da tela descarta o controlador uma única vez', (tester) async {
    await abrirPagina(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('resposta tardia não acessa controlador após sair da tela',
      (tester) async {
    final resposta = Completer<String>();
    when(() => auth.confirmarEmailCadastro(any(), any()))
        .thenAnswer((_) => resposta.future);
    await abrirPagina(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump(const Duration(milliseconds: 500));
    verify(() => auth.confirmarEmailCadastro(any(), any())).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    resposta.completeError(Exception('Código incorreto'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
