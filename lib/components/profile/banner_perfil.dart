import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BannerPerfil extends StatelessWidget {
  const BannerPerfil({super.key, this.url, this.acao});

  final String? url;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final imagem = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3,
        child: ColoredBox(
          color: const Color(0xFFF8D4D1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imagem != null && imagem.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imagem,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              if (acao != null) Positioned(right: 12, bottom: 6, child: acao!),
            ],
          ),
        ),
      ),
    );
  }
}
