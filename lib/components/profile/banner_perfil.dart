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
    final imagem = url?.trim();
    const capaPadrao = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCFB5), Color(0xFFF4ADC0)],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: sobreposicao,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: imagem == null || imagem.isEmpty
                  ? capaPadrao
                  : CachedNetworkImage(
                      imageUrl: imagem,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => capaPadrao,
                      errorWidget: (_, __, ___) => capaPadrao,
                    ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
