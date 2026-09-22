import 'dart:async';

import 'package:flutter/material.dart';
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
  });

  Future<void> abrirPagina(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => Provider<AuthService>.value(
          value: auth,
          child: const MaterialApp(
            home: VerificarEmailCadastro(email: 'cliente@exemplo.com'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

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
    final resposta = Completer<void>();
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
