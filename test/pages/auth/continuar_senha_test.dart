import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:nhac/pages/auth/continuar_senha.dart';
import 'package:nhac/services/auth_service.dart';

class MockAuth extends Mock implements AuthService {}

void main() {
  testWidgets('login preserva os espaços da senha e não oferece novo cadastro', (tester) async {
    final auth = MockAuth();
    final resposta = Completer<void>();
    when(() => auth.login(email: any(named: 'email'), senha: any(named: 'senha')))
        .thenAnswer((_) => resposta.future);
    final cadastro = CadastroController()..setEmail('cliente@teste.com');
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<CadastroController>.value(value: cadastro),
        ],
        child: const MaterialApp(home: ContinuarSenha()),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), ' Senha123 ');
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    verify(() => auth.login(email: 'cliente@teste.com', senha: ' Senha123 ')).called(1);
    expect(find.text('Não tem conta? Criar conta'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    resposta.completeError(Exception('Erro de login'));
    await tester.pump();
    cadastro.dispose();
    expect(tester.takeException(), isNull);
  });
}
