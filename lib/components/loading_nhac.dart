import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingNhac extends StatelessWidget {
  final String? mensagem;
  final bool telaCheia;
  final double tamanho;

  const LoadingNhac({
    super.key,
    this.mensagem,
    this.telaCheia = true,
    this.tamanho = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    final animacao = SizedBox(
      width: tamanho,
      height: tamanho,
      child: Lottie.asset(
        'assets/animations/loading_nhac.json',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(
            Icons.restaurant_rounded,
            color: const Color(0xFFFE645C),
            size: tamanho,
          ),
        ),
      ),
    );
    // Sem legenda, o próprio SizedBox respeita a altura de botões e rodapés.
    Widget loadingContent = mensagem == null
        ? animacao
        : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: animacao),
              if (mensagem != null) ...[
                const SizedBox(height: 16),
                Text(
                  mensagem!,
                  style: TextStyle(
                    color: const Color(0xFF5D201C),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );

    if (telaCheia) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFE7E5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: loadingContent,
          ),
        ),
      );
    }

    return Center(child: loadingContent);
  }

  static void mostrar(BuildContext context, {String? mensagem}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: LoadingNhac(
            mensagem: mensagem,
            telaCheia: false,
            tamanho: 120,
          ),
        ),
      ),
    );
  }

  static void esconder(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
