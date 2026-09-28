import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/pages/dados_pessoais_page.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:provider/provider.dart';

class MockUserProvider extends ChangeNotifier implements UserProvider {
  @override
  UsuarioModel? get usuario => UsuarioModel(
        id: '123',
        nome: 'Usuario Teste',
        email: 'teste@google.com',
        imagemUrl: '',
        telefone: '11999999999',
      );

  @override
  bool get isGoogleUser => true;

  @override
  bool get hasPassword => false;

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
  bool get isPhoneUser => false;
}

void main() {
  Widget createWidgetUnderTest(UserProvider provider, bool isGoogle) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) => MaterialApp(
        home: ChangeNotifierProvider<UserProvider>.value(
          value: provider,
          child: DadosPessoaisPage(isGoogleUserOverride: isGoogle),
        ),
      ),
    );
  }

  testWidgets('Deve mostrar os dados básicos do usuário', (WidgetTester tester) async {
    final mockProvider = MockUserProvider();

    await tester.pumpWidget(createWidgetUnderTest(mockProvider, true));
    await tester.pump();

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('teste@google.com'), findsOneWidget);
    expect(find.text('Usuario Teste'), findsOneWidget);
  });

  testWidgets('Deve habilitar clique para usuário comum', (WidgetTester tester) async {
    final mockProvider = MockUserProvider();

    await tester.pumpWidget(createWidgetUnderTest(mockProvider, false));
    await tester.pump();

    final emailItem = find.ancestor(
      of: find.text('E-mail'),
      matching: find.byType(InkWell),
    );
    
    expect(emailItem, findsOneWidget);

    final inkWell = tester.widget<InkWell>(emailItem);
    expect(inkWell.onTap, isNotNull);
  });
}
