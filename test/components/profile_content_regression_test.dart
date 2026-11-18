import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/components/profile_content.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/repositories/endereco_repository.dart';
import 'package:nhac/repositories/user_repository.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/auth_service.dart';

class ProfileAuthMock extends Mock implements AuthService {}

class ProfileUserMock extends Mock implements UserRepository {}

class ProfileEnderecoMock extends Mock implements EnderecoRepository {}

class ProfilePedidoMock extends Mock implements PedidoRepository {}

void main() {
  late ProfileAuthMock auth;
  late ProfilePedidoMock pedidos;
  late ProfileUserMock users;
  late UserProvider user;
  late EnderecoProvider enderecos;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = ProfileAuthMock();
    users = ProfileUserMock();
    pedidos = ProfilePedidoMock();
    when(() => auth.usuarioId).thenReturn('cliente');
    when(() => auth.isGoogleUser).thenReturn(false);
    when(() => auth.isPhoneUser).thenReturn(false);
    when(() => auth.hasPassword).thenReturn(true);
    when(() => users.buscarUsuario('cliente')).thenAnswer((_) async =>
        UsuarioModel(
            id: 'cliente',
            nome: 'Cliente',
            email: 'cliente@teste.com',
            telefone: '11999999999'));
    when(() => pedidos.buscarEstatisticas('cliente')).thenAnswer((_) async =>
        {'totalPedidos': 7, 'lojasFavoritadas': 3, 'cuponsResgatados': 2});
    user = UserProvider(authService: auth, repository: users);
    enderecos =
        EnderecoProvider(authService: auth, repository: ProfileEnderecoMock());
    await user.carregarDadosUsuario();
  });
  tearDown(() {
    user.dispose();
    enderecos.dispose();
  });

  Future<void> montar(WidgetTester tester, {double largura = 390}) async {
    tester.view.physicalSize = Size(largura * 3, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: ProfileContent(
                  pedidoRepository: pedidos,
                  autenticarBiometria: () async => false))),
      GoRoute(
          path: '/meus-pedidos',
          builder: (_, __) => const Scaffold(body: Text('Histórico aberto'))),
      GoRoute(
          path: '/dados-pessoais',
          builder: (_, __) => const Scaffold(body: Text('Dados abertos'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<EnderecoProvider>.value(value: enderecos),
        ],
        child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp.router(routerConfig: router))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  for (final largura in [390.0, 320.0]) {
    for (final comBanner in [false, true]) {
      testWidgets(
        'perfil mantém a posição original da foto e dos indicadores em $largura com banner $comBanner',
        (tester) async {
          const fotoUrl = 'https://example.com/foto-cliente.png';
          const bannerUrl = 'https://example.com/banner-cliente.png';
          when(() => users.buscarUsuario('cliente')).thenAnswer((_) async =>
              UsuarioModel(
                id: 'cliente',
                nome: 'Cliente',
                email: 'cliente@teste.com',
                telefone: '11999999999',
                imagemUrl: fotoUrl,
                bannerUrl: comBanner ? bannerUrl : null,
              ));
          await user.carregarDadosUsuario();
          await mockNetworkImagesFor(() async {
            await montar(tester, largura: largura);
            final foto = find.byWidgetPredicate(
              (widget) => widget is CachedNetworkImage && widget.imageUrl == fotoUrl,
            );
            final fotoRect = tester.getRect(foto);
            expect(fotoRect.left, closeTo(24 * largura / 390, 0.01));
            expect(fotoRect.top, closeTo(104, 0.01));
            expect(fotoRect.height, closeTo(80, 0.01));
            final pedidos = find.ancestor(
              of: find.text('Pedidos'),
              matching: find.byType(InkWell),
            );
            expect(tester.getTopLeft(pedidos).dy, closeTo(216, 0.01));
            expect(tester.takeException(), isNull);

            if (comBanner) {
              final banner = find.byWidgetPredicate(
                (widget) => widget is CachedNetworkImage && widget.imageUrl == bannerUrl,
              );
              final bannerRect = tester.getRect(banner);
              expect(bannerRect.left, 0);
              expect(bannerRect.width, largura);
              expect(bannerRect.bottom, fotoRect.center.dy);
            }
            if (const bool.fromEnvironment('CAPTURE_UI')) {
              await expectLater(
                find.byType(Scaffold),
                matchesGoldenFile('goldens/perfil-$largura-$comBanner.png'),
              );
            }

            await tester.tap(find.byIcon(Icons.more_horiz));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.text(comBanner ? 'Trocar banner' : 'Adicionar banner'), findsOneWidget);
          });
        },
      );
    }
  }

  testWidgets('cartão Pedidos abre histórico e opção duplicada não aparece',
      (tester) async {
    await montar(tester);
    expect(find.text('Meus pedidos'), findsNothing);
    await tester.tap(find.ancestor(
        of: find.text('Pedidos'), matching: find.byType(InkWell)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Histórico aberto'), findsOneWidget);
  });

  testWidgets('erro de estatística mostra indisponibilidade e retry recupera',
      (tester) async {
    when(() => pedidos.buscarEstatisticas('cliente'))
        .thenThrow(Exception('offline'));
    await montar(tester);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('0'), findsNothing);
    when(() => pedidos.buscarEstatisticas('cliente')).thenAnswer((_) async =>
        {'totalPedidos': 8, 'lojasFavoritadas': 0, 'cuponsResgatados': 4});
    await tester.tap(find.text('Estatísticas indisponíveis. Tentar novamente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('atualização manual consulta estatísticas e usuário novamente',
      (tester) async {
    await montar(tester);
    clearInteractions(pedidos);
    clearInteractions(users);
    when(() => pedidos.buscarEstatisticas('cliente')).thenAnswer((_) async =>
        {'totalPedidos': 9, 'lojasFavoritadas': 3, 'cuponsResgatados': 2});
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    verify(() => pedidos.buscarEstatisticas('cliente')).called(1);
    verify(() => users.buscarUsuario('cliente')).called(1);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('perfil ausente tem retry e não animação infinita',
      (tester) async {
    user.limparUsuario();
    when(() => users.buscarUsuario('cliente')).thenThrow(Exception('offline'));
    await user.carregarDadosUsuario();
    await montar(tester);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Não foi possível carregar o perfil. Tente novamente.'),
        findsOneWidget);
  });

  Future<void> abrirDados(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Dados Pessoais'));
    await tester.tap(find.text('Dados Pessoais'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets('cancelar senha não mostra erro de autenticação', (tester) async {
    await montar(tester);
    await abrirDados(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Confirme sua identidade para continuar'), findsNothing);
    expect(find.text('Dados abertos'), findsNothing);
  });

  testWidgets('falha de senha mostra somente um aviso', (tester) async {
    when(() => auth.confirmarSenha(email: 'cliente@teste.com', senha: 'errada'))
        .thenThrow(Exception('inválida'));
    await montar(tester);
    await abrirDados(tester);
    await tester.enterText(find.byType(TextField), 'errada');
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
        find.text(
            'Não foi possível confirmar a senha. Confira os dados e a conexão.'),
        findsOneWidget);
    expect(find.text('Confirme sua identidade para continuar'), findsNothing);
    expect(find.text('Dados abertos'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('cancelamento Google é silencioso', (tester) async {
    when(() => auth.isGoogleUser).thenReturn(true);
    when(() => auth.confirmarComGoogle()).thenAnswer((_) async => false);
    await montar(tester);
    await abrirDados(tester);
    expect(find.textContaining('Não foi possível confirmar'), findsNothing);
    expect(find.text('Dados abertos'), findsNothing);
  });

  testWidgets('falha Google mostra somente o aviso central', (tester) async {
    when(() => auth.isGoogleUser).thenReturn(true);
    when(() => auth.confirmarComGoogle()).thenThrow(Exception('offline'));
    await montar(tester);
    await abrirDados(tester);
    expect(
        find.text(
            'Não foi possível confirmar sua identidade. Confira a conexão e tente de novo.'),
        findsOneWidget);
    expect(find.text('Confirme sua identidade para continuar'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('falha SMS mostra um aviso e cancelamento é silencioso',
      (tester) async {
    when(() => auth.isPhoneUser).thenReturn(true);
    when(() => auth.telefoneLocal(any())).thenReturn('11999999999');
    when(() => auth.enviarCodigoSms(any())).thenAnswer((_) async {});
    when(() => auth.confirmarComSms(any(), any()))
        .thenThrow(Exception('inválido'));
    await montar(tester);
    await abrirDados(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
        find.text(
            'Não foi possível confirmar sua identidade. Confira a conexão e tente de novo.'),
        findsOneWidget);
    expect(find.text('Confirme sua identidade para continuar'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await abrirDados(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.textContaining('Não foi possível confirmar'), findsNothing);
  });

  testWidgets('voltar dos pedidos consulta estatísticas atualizadas',
      (tester) async {
    await montar(tester);
    await tester.tap(find.ancestor(
        of: find.text('Pedidos'), matching: find.byType(InkWell)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    when(() => pedidos.buscarEstatisticas('cliente')).thenAnswer((_) async =>
        {'totalPedidos': 8, 'lojasFavoritadas': 3, 'cuponsResgatados': 4});
    final ctx = tester.element(find.text('Histórico aberto'));
    GoRouter.of(ctx).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
