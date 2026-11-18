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
                  imageBuilder: (context, image) => Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(image: image, fit: BoxFit.cover),
                    ),
                    foregroundDecoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66FFE7E5), Color(0xD9FFE7E5)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
