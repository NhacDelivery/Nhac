import 'package:nhac/pages/feed_link_page.dart';
import 'package:nhac/pages/feed_page.dart';
import 'package:nhac/pages/produto_link_page.dart';
import 'package:flutter/material.dart';
import 'package:nhac/pages/feed_publish_page.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/pages/auth/cadastro/verificar_email_cadastro.dart';
import 'package:nhac/pages/bem_vindo.dart';
import 'package:nhac/pages/auth/continuar_senha.dart';
import 'package:nhac/pages/auth/email_cliente.dart';
import 'package:nhac/pages/auth/insira_telefone.dart';
import 'package:nhac/pages/carrinho_page.dart';
import 'package:nhac/models/chat/pedido_chat_referencia.dart';
import 'package:nhac/pages/chat_loja_page.dart';
import 'package:nhac/pages/chat_conversa_page.dart';
import 'package:nhac/pages/checkout_page.dart';
import 'package:nhac/pages/pagamento_pendente_page.dart';
import 'package:nhac/pages/meus_pedidos_page.dart';
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
import 'package:nhac/pages/feed_post_detail_page.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/services/home_order_route_observer.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/pages/pedido_entregue_page.dart';
import 'package:nhac/pages/mensagens_page.dart';

class _SlideRightToLeftPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _SlideRightToLeftPageRoute({
    required this.child,
    required super.settings,
    this.slideOnExit = true,
  });

  final Widget child;
  final bool slideOnExit;

  @override
  Widget buildContent(BuildContext context) => child;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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

    if (!slideOnExit) {
      return page;
    }

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
    this.slideOnExit = true,
  });

  final Widget child;
  final bool slideOnExit;

  @override
  Route<T> createRoute(BuildContext context) {
    return _SlideRightToLeftPageRoute<T>(
      child: child,
      settings: this,
      slideOnExit: slideOnExit,
    );
  }
}

Page _buildSlideRightToLeftPage({
  required LocalKey key,
  required Widget child,
  bool slideOnExit = true,
}) {
  return SlideRightToLeftPage(
    key: key,
    child: child,
    slideOnExit: slideOnExit,
  );
}

class _ChatCardExpandPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _ChatCardExpandPageRoute({
    required this.child,
    required super.settings,
    this.cardRect,
  });

  final Widget child;
  final Rect? cardRect;

  @override
  Widget buildContent(BuildContext context) => child;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final screenSize = MediaQuery.sizeOf(context);
    final targetRect =
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    final initialRect = cardRect ??
        Rect.fromLTWH(
          0,
          screenSize.height * 0.35,
          screenSize.width,
          80,
        );

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, _) {
        final t = curvedAnimation.value;
        final currentRect = Rect.lerp(initialRect, targetRect, t)!;
        final currentRadius =
            Radius.circular((16.0 * (1.0 - t)).clamp(0.0, 16.0));

        return Stack(
          children: [
            Positioned.fromRect(
              rect: currentRect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(currentRadius),
                  boxShadow: t < 0.99
                      ? [
                          BoxShadow(
                            color: const Color(0xFF5D201C)
                                .withValues(alpha: 0.14 * (1.0 - t)),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: Offset(0, 6 * (1.0 - t)),
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(currentRadius),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: screenSize.width,
                    maxWidth: screenSize.width,
                    minHeight: screenSize.height,
                    maxHeight: screenSize.height,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ChatCardExpandPage<T> extends Page<T> {
  const ChatCardExpandPage({
    required super.key,
    required this.child,
    this.cardRect,
  });

  final Widget child;
  final Rect? cardRect;

  @override
  Route<T> createRoute(BuildContext context) {
    return _ChatCardExpandPageRoute<T>(
      child: child,
      settings: this,
      cardRect: cardRect,
    );
  }
}

Page _buildChatExpandPage({
  required LocalKey key,
  required Widget child,
  Rect? cardRect,
}) {
  return ChatCardExpandPage(key: key, child: child, cardRect: cardRect);
}

final authServiceRoteador = AuthService();
String? pendingFeedPath;

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [homeOrderRouteObserver],
  refreshListenable: authServiceRoteador,
  redirect: (BuildContext context, GoRouterState state) {
    if (state.uri.path.startsWith('/publicacao/'))
      pendingFeedPath = state.uri.path;
    if (estaSessaoProntaParaFeed()) {
      final path = pendingFeedPath!;
      pendingFeedPath = null;
      if (state.uri.path != path) return path;
    }
    if (!authServiceRoteador.carregado) {
      if (state.matchedLocation == '/splash') return null;
      return state.matchedLocation.startsWith('/produto/')
          ? '/splash?produto=${Uri.encodeQueryComponent(state.uri.path)}'
          : '/splash';
    }

    final bool estaAutenticado = authServiceRoteador.isAuthenticated;

    final bool telaPublica = state.matchedLocation.startsWith('/publicacao/') ||
        state.matchedLocation.startsWith('/produto/') ||
        state.matchedLocation == '/' ||
        state.matchedLocation == '/splash' ||
        state.matchedLocation == '/bem-vindo' ||
        state.matchedLocation == '/bem-vindo-motoca' ||
        state.matchedLocation == '/email-cliente' ||
        state.matchedLocation == '/insira_telefone' ||
        state.matchedLocation == '/verificacao_numero' ||
        state.matchedLocation == '/continuar_senha' ||
        state.matchedLocation.startsWith('/recuperacao') ||
        state.matchedLocation.startsWith('/cadastro');

    final bool noMeioDoCadastro =
        state.matchedLocation == '/verificacao_numero' ||
            state.matchedLocation.startsWith('/cadastro');

    if (!estaAutenticado && !telaPublica) {
      return '/bem-vindo';
    }

    if (estaAutenticado &&
        telaPublica &&
        state.matchedLocation != '/splash' &&
        !state.matchedLocation.startsWith('/produto/') &&
        !state.matchedLocation.startsWith('/publicacao/') &&
        !noMeioDoCadastro) {
      return '/home-page';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/publicacao/:id',
      builder: (_, state) => FeedLinkPage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/feed-salvos',
      builder: (_, __) => const Scaffold(body: FeedPage(salvos: true)),
    ),
    GoRoute(
      path: '/produto/:id',
      builder: (context, state) =>
          ProdutoLinkPage(produtoId: state.pathParameters['id']!),
    ),
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
      pageBuilder: (context, state) =>
          _buildSlideRightToLeftPage(key: state.pageKey, child: const Nome()),
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
        child: CuponsPage(subtotal: (state.extra as num?)?.toDouble()),
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
      path: '/pagamento',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: PagamentoPendentePage(
          pedidoId: state.uri.queryParameters['pedidoId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/meus-pedidos',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const MeusPedidosPage(),
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
        return CustomTransitionPage(
          key: state.pageKey,
          child: RastreioPedidoPage(pedidoId: pedidoId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/pedido-detalhes',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: PedidoEntreguePage(
          pedidoId: state.uri.queryParameters['pedidoId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/pedido-entregue',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: PedidoEntreguePage(
          pedidoId: state.uri.queryParameters['pedidoId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/mensagens',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const MensagensPage(),
        slideOnExit: false,
      ),
    ),
    GoRoute(
      path: '/chat-pessoa',
      pageBuilder: (context, state) {
        final dados = state.extra as Map<String, dynamic>? ?? const {};
        final cardRect = dados['cardRect'] as Rect?;
        return _buildChatExpandPage(
          key: state.pageKey,
          cardRect: cardRect,
          child: ChatConversaPage(
            conversaId: (dados['conversaId'] ?? '').toString(),
            interlocutorNome: (dados['pessoaNome'] ?? 'Pessoa').toString(),
            interlocutorFotoUrl: dados['fotoUrl']?.toString(),
            conversaPessoa: true,
            heroTag: dados['heroTag']?.toString(),
          ),
        );
      },
    ),
    GoRoute(
      path: '/chat-loja',
      pageBuilder: (context, state) {
        final dados = state.extra as Map<String, dynamic>? ?? const {};
        final cardRect = dados['cardRect'] as Rect?;
        return _buildChatExpandPage(
          key: state.pageKey,
          cardRect: cardRect,
          child: ChatLojaPage(
            conversaId: dados['conversaId']?.toString(),
            lojaId: (dados['lojaId'] ?? '').toString(),
            lojaNome: (dados['lojaNome'] ?? 'Loja').toString(),
            lojaFotoUrl: dados['lojaFotoUrl']?.toString() ??
                dados['fotoUrl']?.toString(),
            heroTag: dados['heroTag']?.toString(),
            produtoReferencia: dados['produto'] is ProdutosModel
                ? dados['produto'] as ProdutosModel
                : null,
            pedidoReferencia: dados['pedido'] is PedidoChatReferencia
                ? dados['pedido'] as PedidoChatReferencia
                : null,
          ),
        );
      },
    ),
    GoRoute(
      path: '/feed-publicar',
      pageBuilder: (context, state) => _buildSlideRightToLeftPage(
        key: state.pageKey,
        child: const FeedPublishPage(),
      ),
    ),
    GoRoute(
      path: '/feed-post',
      pageBuilder: (context, state) {
        if (state.extra is! FeedPostModel) {
          // Fallback para caso ocorra hot reload na tela e o extra seja perdido
          return _buildSlideRightToLeftPage(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(child: Text('Post não encontrado')),
            ),
          );
        }

        final post = state.extra as FeedPostModel;
        return CustomTransitionPage(
          key: state.pageKey,
          child: FeedPostDetailPage(
            post: post,
            focarComentario: state.uri.queryParameters['comentar'] == 'true',
          ),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
  ],
);

bool estaSessaoProntaParaFeed() =>
    authServiceRoteador.carregado &&
    authServiceRoteador.isAuthenticated &&
    pendingFeedPath != null;
