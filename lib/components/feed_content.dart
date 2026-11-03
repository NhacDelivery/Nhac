import 'package:flutter/material.dart';

class FeedContent extends StatefulWidget {
  final String conteudo;
  final List<String> tags;
  final int limiteLinhas;
  final bool expandivel;

  const FeedContent({
    super.key,
    required this.conteudo,
    required this.tags,
    this.limiteLinhas = 3,
    this.expandivel = true,
  });

  @override
  State<FeedContent> createState() => _FeedContentState();
}

class _FeedContentState extends State<FeedContent>
    with SingleTickerProviderStateMixin {
  bool _expandido = false;
  late final AnimationController _bounceController;
  late final Animation<double> _jumpAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -3.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -3.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_bounceController);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF5D201C),
      height: 1.5,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.conteudo, style: textStyle);
        final tp = TextPainter(
          text: span,
          maxLines: widget.limiteLinhas,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final ultrapassaLimite = tp.didExceedMaxLines;
        final mostrarBotao = widget.expandivel && ultrapassaLimite;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conteudo,
              maxLines: (!widget.expandivel || _expandido)
                  ? null
                  : widget.limiteLinhas,
              overflow: (!widget.expandivel || _expandido)
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: textStyle,
            ),
            if (mostrarBotao)
              GestureDetector(
                onTap: () {
                  _bounceController.forward(from: 0.0);
                  setState(() => _expandido = !_expandido);
                },
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _jumpAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expandido ? 'Ler menos' : 'Ler mais',
                          style: const TextStyle(
                            color: Color(0xFFFF6961),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expandido
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: const Color(0xFFFF6961),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.tags
                      .toSet()
                      .map(
                        (tag) => Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFFF6961),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}
