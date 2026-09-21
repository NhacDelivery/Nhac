import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/components/nhac_input_field.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/pages/editar_perfil/editar_email_page.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:provider/provider.dart';

class MockUserProvider extends ChangeNotifier implements UserProvider {
  @override
  UsuarioModel? get usuario => UsuarioModel(
        id: '123',
        nome: 'Usuario Teste',
        email: 'atual@nhac.com',
        imagemUrl: '',
        telefone: '11999999999',
      );

  @override
  bool get isGoogleUser => false;

  @override
  bool get hasPassword => true;

  @override
  bool get isLoading => false;

  @override
  void limparUsuario() {}

  @override
  bool get hasListeners => false;

  @override
  Future<void> atualizarFotoPerfil(File imagem) async {}

  @override
  Future<void> carregarDadosUsuario() async {}

  @override
  // TODO: implement isPhoneUser
  bool get isPhoneUser => throw UnimplementedError();
}

class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isAuthenticated => true;
  @override
  bool get carregado => true;
  @override
  String? get usuarioId => '123';
  @override
  String? get nome => 'Usuario Teste';
  @override
  bool get isGoogleUser => false;
  @override
  bool get hasPassword => true;

  @override
  Future<void> login({required String email, required String senha}) async {}
  @override
  Future<void> loginComGoogle() async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> registrar({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {}
  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateEmail({required String novoEmail}) async {}

  @override
  Future<void> updateUserName({required String userName}) async {}

  @override
  Future<void> enviarCodigoSms(String telefone) async {}

  @override
  String formatarTelefoneE164(String telefoneBR) => telefoneBR;

  @override
  Future<bool> loginSms(String telefone, String codigo) async => true;

  @override
  Future<void> updateFcmToken({required String fcmToken}) async {}

  @override
  Future<bool> checarEmail(String email) async {
    return false;
  }

  @override
  Future<void> alterarSenha(String senhaAtual, String novaSenha) {
    // TODO: implement alterarSenha
    throw UnimplementedError();
  }

  @override
  Future<void> esqueciSenhaEmail(String email, {CancelToken? cancelToken}) {
    // TODO: implement esqueciSenhaEmail
    throw UnimplementedError();
  }

  @override
  Future<void> redefinirSenhaEmail(String email, String codigo, String novaSenha) {
    // TODO: implement redefinirSenhaEmail
    throw UnimplementedError();
  }

  @override
  // TODO: implement isPhoneUser
  bool get isPhoneUser => throw UnimplementedError();

  @override
  Future<void> confirmarEmailCadastro(String email, String codigo) {
    // TODO: implement confirmarEmailCadastro
    throw UnimplementedError();
  }

  @override
  Future<void> enviarCodigoCadastro(String email) {
    // TODO: implement enviarCodigoCadastro
    throw UnimplementedError();
  }
}

void main() {
  Widget createWidgetUnderTest({
    required UserProvider userProvider,
    required AuthService authService,
  }) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<AuthService>.value(value: authService),
        ],
        child: const MaterialApp(
          home: EditarEmailPage(),
        ),
      ),
    );
  }

  group('EditarEmailPage Tests', () {
    testWidgets('Botão deve iniciar desabilitado quando campo está vazio',
        (WidgetTester tester) async {
      final mockUser = MockUserProvider();
      final mockAuth = MockAuthService();

      await tester.pumpWidget(
          createWidgetUnderTest(userProvider: mockUser, authService: mockAuth));
      await tester.pumpAndSettle();

      final botaoFinder = find.byType(BotaoLargoNhac);
      expect(botaoFinder, findsOneWidget);

      final botao = tester.widget<BotaoLargoNhac>(botaoFinder);
      expect(botao.onPressed, isNull);
    });

    testWidgets(
        'Botão deve ficar bloqueado e exibir erro se digitar o e-mail atual',
        (WidgetTester tester) async {
      final mockUser = MockUserProvider();
      final mockAuth = MockAuthService();

      await tester.pumpWidget(
          createWidgetUnderTest(userProvider: mockUser, authService: mockAuth));
      await tester.pumpAndSettle();

      final inputFinder = find.byType(NhacInputField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'atual@nhac.com');
      await tester.pumpAndSettle();

      expect(find.text('Este e-mail já está sendo utilizado pela sua conta'),
          findsOneWidget);

      final botao = tester.widget<BotaoLargoNhac>(find.byType(BotaoLargoNhac));
      expect(botao.onPressed, isNull);
    });

    testWidgets('Botão deve ficar habilitado se digitar um novo e-mail válido',
        (WidgetTester tester) async {
      final mockUser = MockUserProvider();
      final mockAuth = MockAuthService();

      await tester.pumpWidget(
          createWidgetUnderTest(userProvider: mockUser, authService: mockAuth));
      await tester.pumpAndSettle();

      final inputFinder = find.byType(NhacInputField);
      await tester.enterText(inputFinder, 'novo@nhac.com');
      await tester.pumpAndSettle();

      expect(find.text('Este e-mail já está sendo utilizado pela sua conta'),
          findsNothing);

      final botao = tester.widget<BotaoLargoNhac>(find.byType(BotaoLargoNhac));
      expect(botao.onPressed, isNotNull);
    });

    testWidgets('Botão deve ficar bloqueado se e-mail for inválido',
        (WidgetTester tester) async {
      final mockUser = MockUserProvider();
      final mockAuth = MockAuthService();

      await tester.pumpWidget(
          createWidgetUnderTest(userProvider: mockUser, authService: mockAuth));
      await tester.pumpAndSettle();

      final inputFinder = find.byType(NhacInputField);
      await tester.enterText(inputFinder, 'emailinvalido');
      await tester.pumpAndSettle();

      expect(find.text('E-mail inválido'), findsOneWidget);

      final botao = tester.widget<BotaoLargoNhac>(find.byType(BotaoLargoNhac));
      expect(botao.onPressed, isNull);
    });
  });
}
