import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/push_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2400), 
      vsync: this,
    );

    
    _animationController.forward().then((_) {
      
      Future.delayed(const Duration(seconds: 1), () async {
        final email = await LocalCacheService.carregarEmailVerificacao();
        if (!mounted) return;
        if (pendingFeedPath != null) { context.go(pendingFeedPath!); return; }
        final produto = GoRouterState.of(context).uri.queryParameters['produto'];
        if (produto != null && produto.startsWith('/produto/')) {
          context.go(produto);
          return;
        }
        final pedidoPendente = PushNotificationService.pendingPedidoId;
        if (authServiceRoteador.isAuthenticated && pedidoPendente != null) {
          PushNotificationService.pendingPedidoId = null;
          context.go('/rastreio?pedidoId=${Uri.encodeQueryComponent(pedidoPendente)}');
          return;
        }
        if (!authServiceRoteador.isAuthenticated && email != null && email.isNotEmpty) {
          context.go('/cadastro/verificar-email', extra: email);
        } else {
          context.go('/home-page');
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: Center(
        child: Lottie.asset(
          'assets/animations/nhac-intro.json',
          controller: _animationController,
          onLoaded: (composition) {
            
            _animationController.duration =
                composition.duration * 0.4; 
          },
        ),
      ),
    );
  }
}
