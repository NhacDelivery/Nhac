import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Dados herdados que permitem qualquer widget descendente disparar a animação.
class FlyToCartData extends InheritedWidget {
  final void Function(Offset origin, String imageUrl) fly;

  const FlyToCartData({
    super.key,
    required this.fly,
    required super.child,
  });

  @override
  bool updateShouldNotify(FlyToCartData oldWidget) => fly != oldWidget.fly;
}

/// Widget wrapper que fornece a funcionalidade de animação fly-to-cart.
///
/// Uso:
/// ```dart
/// FlyToCartOverlay(
///   cartIconKey: _cartIconKey,
///   onLanded: () { /* bounce the cart icon */ },
///   child: ...,
/// )
/// ```
///
/// Para disparar:
/// ```dart
/// FlyToCartOverlay.of(context)?.fly(originOffset, imageUrl);
/// ```
class FlyToCartOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey cartIconKey;
  final VoidCallback? onLanded;

  const FlyToCartOverlay({
    super.key,
    required this.child,
    required this.cartIconKey,
    this.onLanded,
  });

  /// Retorna o callback `fly` disponível no contexto, ou null se não houver.
  static FlyToCartData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FlyToCartData>();
  }

  @override
  State<FlyToCartOverlay> createState() => _FlyToCartOverlayState();
}

class _FlyToCartOverlayState extends State<FlyToCartOverlay>
    with TickerProviderStateMixin {
  final List<_FlyingItem> _flyingItems = [];

  void _fly(Offset origin, String imageUrl) {
    // Calcula o destino: centro do ícone do carrinho na navbar.
    final cartRenderBox =
        widget.cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartRenderBox == null || !cartRenderBox.attached) return;

    final cartPosition = cartRenderBox.localToGlobal(
      cartRenderBox.size.center(Offset.zero),
    );

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    final item = _FlyingItem(
      controller: controller,
      origin: origin,
      destination: cartPosition,
      imageUrl: imageUrl,
    );

    setState(() => _flyingItems.add(item));

    controller.forward().then((_) {
      widget.onLanded?.call();
      if (mounted) {
        setState(() => _flyingItems.remove(item));
      }
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final item in _flyingItems) {
      item.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlyToCartData(
      fly: _fly,
      child: Stack(
        children: [
          widget.child,
          // Camada de animações voando
          ..._flyingItems.map((item) => _FlyingWidget(item: item)),
        ],
      ),
    );
  }
}

/// Dados de um item em voo.
class _FlyingItem {
  final AnimationController controller;
  final Offset origin;
  final Offset destination;
  final String imageUrl;

  _FlyingItem({
    required this.controller,
    required this.origin,
    required this.destination,
    required this.imageUrl,
  });
}

/// Widget que renderiza a miniatura voando em arco parabólico.
class _FlyingWidget extends StatelessWidget {
  final _FlyingItem item;

  const _FlyingWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: item.controller,
      builder: (context, child) {
        final t = item.controller.value;
        final curvedT = Curves.easeInOutCubic.transform(t);

        // Posição X: interpolação linear
        final x =
            item.origin.dx + (item.destination.dx - item.origin.dx) * curvedT;

        // Posição Y: interpolação com arco parabólico (sobe e desce)
        final linearY =
            item.origin.dy + (item.destination.dy - item.origin.dy) * curvedT;
        // Parábola: -4 * t * (t - 1) dá pico em t=0.5 com valor 1.0
        final arcHeight = 120.h;
        final parabola = -4 * curvedT * (curvedT - 1);
        final y = linearY - (arcHeight * parabola);

        // Escala: 1.0 → 0.3
        final scale = 1.0 - 0.7 * Curves.easeIn.transform(t);

        // Opacidade: mantém 1.0 até 75%, depois fade out
        final opacity =
            t < 0.75 ? 1.0 : (1.0 - ((t - 0.75) / 0.25)).clamp(0.0, 1.0);

        // Rotação sutil
        final rotation = -0.25 * Curves.easeIn.transform(t);

        final size = 50.r;

        return Positioned(
          left: x - size / 2,
          top: y - size / 2,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6961).withValues(alpha: 0.4),
                          blurRadius: 12.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFFFF0EE),
                          child: Icon(Icons.fastfood_rounded,
                              color: const Color(0xFFFF6961), size: 20.r),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFFFF0EE),
                          child: Icon(Icons.fastfood_rounded,
                              color: const Color(0xFFFF6961), size: 20.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
