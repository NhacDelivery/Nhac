// Re-export LoadingNhac for convenience
export 'loading_nhac.dart' show LoadingNhac;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/loading_nhac.dart';

/// Widget reutilizável para estados de loading, vazio e erro com botão "Tentar novamente".
///
/// Estados suportados:
/// - [EstadoConteudo.loading]: exibe shimmer/skeleton ou Lottie de loading
/// - [EstadoConteudo.vazio]: ilustração + mensagem amigável
/// - [EstadoConteudo.erro]: cor coral, ícone de erro, botão "Tentar novamente"
/// - [EstadoConteudo.conteudo]: exibe o widget filho com os dados
///
/// Uso típico:
/// ```dart
/// EstadoComRetry<ProdutosModel>(
///   estado: _estado,
///   aoTentarNovamente: _fetchProdutos,
///   builderVazio: () => const Text('Nenhum produto encontrado'),
///   builderErro: (erro, tentarNovamente) => ...
///   builderConteudo: (dados) => ListaProdutos(produtos: dados),
/// )
/// ```
enum EstadoConteudo { loading, vazio, erro, conteudo }

class EstadoComRetry<T> extends StatelessWidget {
  /// Estado atual do conteúdo
  final EstadoConteudo estado;

  /// Dados carregados (quando estado == conteudo)
  final T? dados;

  /// Mensagem de erro (quando estado == erro)
  final String? mensagemErro;

  /// Callback para tentar novamente (chamado no botão "Tentar novamente")
  final Future<void> Function()? aoTentarNovamente;

  /// Builder para o estado de loading (opcional, usa shimmer padrão se null)
  final Widget Function()? builderLoading;

  /// Builder para o estado vazio (opcional, usa padrão se null)
  final Widget Function()? builderVazio;

  /// Builder para o estado de erro (opcional, usa padrão se null)
  final Widget Function(String erro, VoidCallback tentarNovamente)? builderErro;

  /// Builder para o conteúdo (obrigatório quando estado == conteudo)
  final Widget Function(T dados) builderConteudo;

  /// Altura mínima do container (útil para evitar layout shift)
  final double? alturaMinima;

  /// Se deve mostrar shimmer personalizado no loading
  final bool usarShimmer;

  const EstadoComRetry({
    super.key,
    required this.estado,
    required this.builderConteudo,
    this.dados,
    this.mensagemErro,
    this.aoTentarNovamente,
    this.builderLoading,
    this.builderVazio,
    this.builderErro,
    this.alturaMinima,
    this.usarShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (estado) {
      case EstadoConteudo.loading:
        return _buildLoading();
      case EstadoConteudo.vazio:
        return _buildVazio();
      case EstadoConteudo.erro:
        final anteriores = dados;
        if (anteriores != null &&
            (anteriores is! Iterable || anteriores.isNotEmpty)) {
          return Column(
            children: [
              BannerErroInline(
                mensagem:
                    mensagemErro ??
                    'Não foi possível atualizar. Exibindo dados anteriores.',
                aoTentarNovamente: aoTentarNovamente,
              ),
              builderConteudo(anteriores),
            ],
          );
        }
        return _buildErro();
      case EstadoConteudo.conteudo:
        final T? currentDados = dados;
        return currentDados != null
            ? builderConteudo(currentDados)
            : _buildVazio();
    }
  }

  Widget _buildLoading() {
    if (builderLoading != null) {
      return builderLoading!();
    }

    return _ShimmerPlaceholder(
      alturaMinima: alturaMinima,
      usarShimmer: usarShimmer,
    );
  }

  Widget _buildVazio() {
    if (builderVazio != null) {
      return builderVazio!();
    }

    return _EstadoVazioPadrao(alturaMinima: alturaMinima);
  }

  Widget _buildErro() {
    if (builderErro != null) {
      final erroWidget = builderErro!(
        mensagemErro ?? 'Erro desconhecido',
        _tentarNovamente,
      );
      if (alturaMinima != null) {
        return SizedBox(height: alturaMinima, child: erroWidget);
      }
      return erroWidget;
    }

    return _EstadoErroPadrao(
      mensagem: mensagemErro ?? 'Erro ao carregar',
      aoTentarNovamente: _tentarNovamente,
      alturaMinima: alturaMinima,
    );
  }

  void _tentarNovamente() {
    if (aoTentarNovamente != null) {
      aoTentarNovamente!();
    }
  }
}

/// Shimmer placeholder padrão para listas/grids
class _ShimmerPlaceholder extends StatefulWidget {
  final double? alturaMinima;
  final bool usarShimmer;

  const _ShimmerPlaceholder({this.alturaMinima, this.usarShimmer = true});

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.usarShimmer) {
      return SizedBox(
        height: widget.alturaMinima ?? 200.h,
        child: const LoadingNhac(telaCheia: false, tamanho: 80),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.alturaMinima ?? 200.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Row(
                  children: [
                    // Imagem placeholder
                    Container(
                      width: 100.w,
                      height: 100.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200.withValues(
                          alpha: _animation.value,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Texto placeholder
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 16.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withValues(
                                alpha: _animation.value,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            width: 120.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withValues(
                                alpha: _animation.value * 0.7,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            width: 80.w,
                            height: 14.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withValues(
                                alpha: _animation.value * 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Estado vazio padrão com ilustração e mensagem
class _EstadoVazioPadrao extends StatelessWidget {
  final double? alturaMinima;

  const _EstadoVazioPadrao({this.alturaMinima});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alturaMinima ?? 250.h,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ilustração vazia
              Container(
                width: 140.w,
                height: 140.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7E5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 64.r,
                  color: const Color(0xFFFF6961).withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Nada por aqui',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D201C),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'Nenhum item encontrado. Volte mais tarde!',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de erro padrão com cor coral, ícone e botão "Tentar novamente"
class _EstadoErroPadrao extends StatelessWidget {
  final String mensagem;
  final VoidCallback? aoTentarNovamente;
  final double? alturaMinima;

  const _EstadoErroPadrao({
    required this.mensagem,
    this.aoTentarNovamente,
    this.alturaMinima,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alturaMinima ?? 250.h,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone de erro com fundo coral
              Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6961).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 40.r,
                  color: const Color(0xFFFF6961),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Ops! Algo deu errado',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D201C),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                mensagem,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (aoTentarNovamente != null) ...[
                SizedBox(height: 16.h),
                Semantics(
                  button: true,
                  label: 'Tentar novamente',
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton.icon(
                      onPressed: aoTentarNovamente,
                      icon: Icon(Icons.refresh_rounded, size: 18.r),
                      label: Text(
                        'Tentar novamente',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6961),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                        elevation: 0,
                        minimumSize: Size(double.infinity, 48.h),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Variante compacta do EstadoComRetry para uso inline (ex: dentro de cards)
class EstadoComRetryCompacto<T> extends StatelessWidget {
  final EstadoConteudo estado;
  final T? dados;
  final String? mensagemErro;
  final Future<void> Function()? aoTentarNovamente;
  final Widget Function(T dados) builderConteudo;
  final Widget Function()? builderLoading;
  final Widget Function()? builderVazio;
  final Widget Function(String erro, VoidCallback tentarNovamente)? builderErro;
  final double? altura;

  const EstadoComRetryCompacto({
    super.key,
    required this.estado,
    required this.builderConteudo,
    this.dados,
    this.mensagemErro,
    this.aoTentarNovamente,
    this.builderLoading,
    this.builderVazio,
    this.builderErro,
    this.altura,
  });

  @override
  Widget build(BuildContext context) {
    switch (estado) {
      case EstadoConteudo.loading:
        final Widget Function()? loadingBuilder = builderLoading;
        return loadingBuilder != null
            ? loadingBuilder()
            : SizedBox(
                height: altura ?? 120.h,
                child: const LoadingNhac(telaCheia: false, tamanho: 60),
              );
      case EstadoConteudo.vazio:
        final Widget Function()? vazioBuilder = builderVazio;
        return vazioBuilder != null
            ? vazioBuilder()
            : SizedBox(
                height: altura ?? 120.h,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 32.r,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Nenhum item',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
      case EstadoConteudo.erro:
        return builderErro != null
            ? builderErro!(mensagemErro ?? 'Erro', _tentarNovamente)
            : SizedBox(
                height: altura ?? 120.h,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 32.r,
                        color: const Color(0xFFFF6961),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        mensagemErro ?? 'Erro',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFFFF6961),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (aoTentarNovamente != null) ...[
                        SizedBox(height: 8.h),
                        TextButton.icon(
                          onPressed: _tentarNovamente,
                          icon: Icon(Icons.refresh_rounded, size: 16.r),
                          label: Text(
                            'Tentar novamente',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFFFF6961),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
      case EstadoConteudo.conteudo:
        final T? currentDados = dados;
        return currentDados != null
            ? builderConteudo(currentDados)
            : const SizedBox.shrink();
    }
  }

  void _tentarNovamente() {
    if (aoTentarNovamente != null) {
      aoTentarNovamente!();
    }
  }
}

/// Banner de erro inline para uso no topo de listas/cards (não full screen)
class BannerErroInline extends StatelessWidget {
  final String mensagem;
  final VoidCallback? aoTentarNovamente;
  final VoidCallback? aoDispensar;
  final Color? corFundo;
  final Color? corTexto;

  const BannerErroInline({
    super.key,
    required this.mensagem,
    this.aoTentarNovamente,
    this.aoDispensar,
    this.corFundo,
    this.corTexto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: corFundo ?? const Color(0xFFFF6961).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFFF6961).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20.r,
            color: const Color(0xFFFF6961),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(
                fontSize: 13.sp,
                color: corTexto ?? const Color(0xFF5D201C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (aoTentarNovamente != null) ...[
            TextButton(
              onPressed: aoTentarNovamente,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                minimumSize: Size(0, 32.h),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Tentar novamente',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6961),
                ),
              ),
            ),
          ],
          if (aoDispensar != null) ...[
            IconButton(
              onPressed: aoDispensar,
              icon: Icon(
                Icons.close_rounded,
                size: 18.r,
                color: const Color(0xFFFF6961),
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
            ),
          ],
        ],
      ),
    );
  }
}
