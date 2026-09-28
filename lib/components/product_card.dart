import 'dart:math';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:provider/provider.dart';
import 'package:nhac/components/app_notification.dart';
import 'package:nhac/globals/ui_utils.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.produto,
    this.lojaFechada = false,
    this.onFlyToCart,
  });

  final ProdutosModel produto;
  final bool lojaFechada;
  /// Callback que recebe a posição global do botão "+" e a URL da imagem
  /// para disparar a animação fly-to-cart. Se null, não dispara animação.
  final void Function(Offset origin, String imageUrl)? onFlyToCart;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160.w,
      margin: EdgeInsets.only(right: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D201C).withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                  child: CachedNetworkImage(
                    imageUrl: widget.produto.imagemUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFFFF0EE),
                      child: Icon(Icons.image_not_supported_outlined,
                          color: const Color(0xFF5D201C), size: 32.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.produto.nome,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: const Color(0xFF5D201C)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text("500g",
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12.sp)),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'R\$ ${widget.produto.preco.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: const Color(0xFF5D201C)),
                      ),
                    ),
                    Builder(
                      builder: (btnContext) {
                        return AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final sineValue = sin(5 * pi * _shakeController.value);
                            return Transform.translate(
                              offset: Offset(sineValue * 2, 2),
                              child: child,
                            );
                          },
                          child: InkWell(
                            onTap: () async {
                              if (widget.lojaFechada) {
                                context.showError('Esta loja está fechada no momento.');
                                _triggerShake();
                                return;
                              }

                              try {
                                final cartProvider = context.read<CartProvider>();
                                await cartProvider.adicionarItemComQuantidade(
                                  idProduto: widget.produto.id,
                                  nome: widget.produto.nome,
                                  preco: widget.produto.preco,
                                  imagemUrl: widget.produto.imagemUrl,
                                  lojaId: widget.produto.lojaId,
                                  quantidade: 1,
                                );
                                
                                if (context.mounted) {
                                  if (widget.onFlyToCart != null) {
                                    final renderBox = btnContext.findRenderObject() as RenderBox?;
                                    if (renderBox != null && renderBox.attached) {
                                      final origin = renderBox.localToGlobal(
                                        renderBox.size.center(Offset.zero),
                                      );
                                      widget.onFlyToCart!(origin, widget.produto.imagemUrl);
                                    }
                                  }

                                  showAppNotification(
                                    context,
                                    type: NotificationType.success,
                                    imageUrl: widget.produto.imagemUrl,
                                    message: '${widget.produto.nome} adicionado!',
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  context.showError(e.toString().replaceAll('Exception: ', ''));
                                  _triggerShake();
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                  color: widget.lojaFechada ? Colors.grey.shade400 : const Color(0xFF5D201C),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.add, color: Colors.white, size: 16.r),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
