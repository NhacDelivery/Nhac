import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BannerPerfil extends StatelessWidget {
  const BannerPerfil({
    super.key,
    this.url,
    required this.sobreposicao,
    required this.child,
  });

  final String? url;
  final double sobreposicao;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final imagem = url;
    return Stack(
      children: [
        if (imagem != null && imagem.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: sobreposicao,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CachedNetworkImage(
                  imageUrl: imagem,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
