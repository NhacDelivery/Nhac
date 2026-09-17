import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/pages/auth/cadastro/verificar_email_cadastro.dart';
import 'package:nhac/pages/bem_vindo.dart';
import 'package:nhac/pages/auth/continuar_senha.dart';
import 'package:nhac/pages/auth/email_cliente.dart';
import 'package:nhac/pages/auth/insira_telefone.dart';
import 'package:nhac/pages/carrinho_page.dart';
import 'package:nhac/pages/chat_loja_page.dart';
import 'package:nhac/pages/checkout_page.dart';
import 'package:nhac/pages/rastreio_pedido_page.dart';
import 'package:nhac/pages/splash_screen.dart';
import 'package:nhac/pages/bem_vindo_motoca.dart';
import 'package:nhac/pages/auth/verificacao_numero.dart';
import 'package:nhac/pages/home_page.dart';
import 'package:nhac/pages/auth/cadastro/nome.dart';
import 'package:nhac/pages/auth/cadastro/senha.dart';
import 'package:nhac/pages/dados_pessoais_page.dart';
import 'package:nhac/pages/editar_perfil/editar_nome_preferencia_page.dart';
import 'package:nhac/pages/editar_perfil/editar_email_page.dart';
import 'package:nhac/pages/editar_perfil/editar_foto_page.dart';
import 'package:nhac/pages/editar_perfil/editar_senha_page.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:nhac/pages/auth/cadastro/telefone_cadastro.dart';
import 'package:nhac/pages/enderecos_page.dart';
import 'package:nhac/pages/formas_pagamento_page.dart';
import 'package:nhac/pages/cupons_page.dart';
import 'package:nhac/pages/search_page.dart';
import 'package:nhac/pages/auth/recuperacao_senha/recuperacao_input_page.dart';
import 'package:nhac/pages/auth/recuperacao_senha/inserir_codigo_recuperacao_page.dart';
import 'package:nhac/pages/auth/recuperacao_senha/nova_senha_recuperacao_page.dart';

class _SlideRightToLeftPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _SlideRightToLeftPageRoute({
    required this.child,
    required super.settings,
  });

  final Widget child;

  @override
  Widget buildContent(BuildContext context) => child;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    var curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );
    var curvedSecondaryAnimation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );

    var enterTween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero);
    var exitTween = Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0));

    Widget page = SlideTransition(
      position: enterTween.animate(curvedAnimation),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0xFF5D201C).withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
    );

    return SlideTransition(
      position: exitTween.animate(curvedSecondaryAnimation),
      child: page,
    );
  }
}

class SlideRightToLeftPage<T> extends Page<T> {
  const SlideRightToLeftPage({
    required super.key,
    required this.child,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return _SlideRightToLeftPageRoute<T>(
      child: child,
      settings: this,
    );
  }
}

Page _buildSlideRightToLeftPage({
  required LocalKey key,
  required Widget child,
}) {
  return SlideRightToLeftPage(key: key, child: child);
}

final authServiceRoteador = AuthService();

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: authServiceRoteador,
 redirect: (BuildContext context, GoRouterState state) {
    if (!authServiceRoteador.carregado) {
      return '/splash';
    }

    final bool estaAutenticado = authServiceRoteador.isAuthenticated;

    final bool telaPublica = state.matchedLocation == '/' ||
        state.matchedLocation == '/splash' ||
        state.matchedLocation == '/bem-vindo' ||
        state.matchedLocation == '/bem-vindo-motoca' ||
        state.matchedLocation == '/email-cliente' ||
        state.matchedLocation == '/insira_telefone' ||
        state.matchedLocation == '/verificacao_numero' ||
        state.matchedLocation == '/continuar_senha' ||
        state.matchedLocation.startsWith('/recuperacao') ||
        state.matchedLocation.startsWith('/cadastro');

    final bool noMeioDoCadastro = state.matchedLocation == '/verificacao_numero' || 
                                  state.matchedLocation.startsWith('/cadastro');

    if (!estaAutenticado && !telaPublica) {
      return '/bem-vindo';
    }

    if (estaAutenticado && telaPublica && state.matchedLocation != '/splash' && !noMeioDoCadastro) {
      return '/home-page';
    }

    return null; 
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/home-page',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const HomePage(),
      ),
    ),
    GoRoute(
      path: '/bem-vindo',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const BemVindo(),
      ),
    ),
    GoRoute(
      path: '/bem-vindo-motoca',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const BemVindoMotoca(),
      ),
    ),
    GoRoute(
      path: '/email-cliente',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const EmailCliente(),
      ),
    ),
    GoRoute(
      path: '/cadastro/senha',
      pageBuilder: (context, state) {
        return _buildSlideRightToLeftPage(
          key: state.pageKey,
          child: const Senha(),
        );
      },
    ),
    GoRoute(
      path: '/cadastro/nome',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const Nome(),
      ),
    ),
    GoRoute(
      path: '/cadastro/verificar-email',
      pageBuilder: (context, state) {
        final email = state.extra as String? ?? '';
        return _buildSlideRightToLeftPage(
          key: state.pageKey,
          child: VerificarEmailCadastro(email: email),
        );
      },
    ),
    GoRoute(
      path: '/cadastro/telefone',
      builder: (context, state) => const TelefoneCadastro(),
    ),
    GoRoute(
      path: '/verificacao_numero',
      pageBuilder: (context, state) {
        final numeroRecebido = state.extra as String? ?? '';
        return _buildSlideRightToLeftPage(
          key: state.pageKey,
          child: VerificacaoNumero(numero: numeroRecebido),
        );
      },
    ),
    GoRoute(
      path: '/insira_telefone',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const InsiraTelefone(),
      ),
    ),
    GoRoute(
      path: '/continuar_senha',
      pageBuilder: (context, state) {
        return _buildSlideRightToLeftPage(
          key: state.pageKey,
          child: const ContinuarSenha(),
        );
      },
    ),
    GoRoute(
      path: '/dados-pessoais',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const DadosPessoaisPage(),
      ),
    ),
    GoRoute(
      path: '/editar-nome-preferencia',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const EditarNomePreferenciaPage(),
      ),
    ),
    GoRoute(
      path: '/editar-email',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const EditarEmailPage(),
      ),
    ),
    GoRoute(
      path: '/editar-foto',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const EditarFotoPage(),
      ),
    ),
    GoRoute(
      path: '/editar-senha',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const EditarSenhaPage(),
      ),
    ),

    GoRoute(
      path: '/enderecos-salvos',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const EnderecosPage(),
      ),
    ),
    GoRoute(
      path: '/formas-pagamento',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const FormasPagamentoPage(),
      ),
    ),
    GoRoute(
      path: '/cupons',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const CuponsPage(),
      ),
    ),
    GoRoute(
    path: '/carrinho',
    pageBuilder: (context, state) => _buildSlideRightToLeftPage(
      key: state.pageKey,
      child: const CarrinhoPage(),
    ),
  ),
  GoRoute(
    path: '/checkout',
    pageBuilder: (context, state) => _buildSlideRightToLeftPage(
      key: state.pageKey,
      child: const CheckoutPage(),
    ),
  ),
  GoRoute(
    path: '/search',
    pageBuilder: (context, state) {
      final categoria = state.uri.queryParameters['categoria'];
      return _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: SearchPage(initialCategory: categoria),
      );
    },
  ),
  GoRoute(
    path: '/recuperacao/input',
    pageBuilder: (context, state) {
      final metodo = state.extra as String? ?? 'email';
      return _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: RecuperacaoInputPage(metodo: metodo),
      );
    },
  ),
  GoRoute(
    path: '/recuperacao/codigo',
    pageBuilder: (context, state) {
      final data = state.extra as Map<String, dynamic>? ?? {};
      return _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: InserirCodigoRecuperacaoPage(
          metodo: data['metodo'] ?? 'email',
          contato: data['contato'] ?? '',
        ),
      );
    },
  ),
  GoRoute(
    path: '/recuperacao/nova-senha',
    pageBuilder: (context, state) {
      final data = state.extra as Map<String, dynamic>? ?? {};
      return _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: NovaSenhaRecuperacaoPage(
          metodo: data['metodo'] ?? 'email',
          contato: data['contato'] ?? '',
          codigo: data['codigo'] ?? '',
        ),
      );
    },
  ),
  GoRoute(
    path: '/rastreio',
    pageBuilder: (context, state) {
      final pedidoId = state.uri.queryParameters['pedidoId'] ?? '';
      return _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: RastreioPedidoPage(pedidoId: pedidoId),
      );
    },
  ),
      GoRoute(
      path: '/chat-loja',
      pageBuilder: (context, state) {
        final dados = state.extra as Map<String, dynamic>? ?? const {};
        return _buildSlideRightToLeftPage(
          key: state.pageKey,
          child: ChatLojaPage(
            lojaId: (dados['lojaId'] ?? '').toString(),
            lojaNome: (dados['lojaNome'] ?? 'Loja').toString(),
          ),
        );
      },
    ),
  ],
  );
