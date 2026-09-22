import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/product_card.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/pages/produto_detalhes_page.dart';

class HomeProductSection extends StatelessWidget {
  const HomeProductSection({
    super.key,
    required this.title,
    required this.products,
    this.onSeeAll,
    this.lojaAberta = const {},
    this.onFlyToCart,
  });

  final String title;
  final List<ProdutosModel> products;
  final VoidCallback? onSeeAll;
  final Map<String, bool> lojaAberta;

  /// Callback para animação fly-to-cart.
  final void Function(Offset origin, String imageUrl)? onFlyToCart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
                color: const Color(0xFF5D201C),
              ),
            ),
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'Ver tudo',
                style: TextStyle(
                  color: const Color(0xFFFF6961),
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        products.isEmpty
            ? SizedBox(
                height: 50.h,
                child: Center(
                  child: Text(
                    'Nenhum produto disponível no momento.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: 220.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final item = products[index];
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        ProdutoDetalhesPage(produto: item),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(0.0, 1.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeOutCubic;

                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));

                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 300),
                              ),
                            );
                          },
                          child: ProductCard(
                            produto: item,
                            lojaFechada:
                                (lojaAberta[item.lojaId] ?? false) == false,
                            onFlyToCart: onFlyToCart,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ],
    );
  }
}
