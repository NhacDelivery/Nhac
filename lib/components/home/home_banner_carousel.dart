import 'package:flutter_screenutil/flutter_screenutil.dart';  
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/globals/app_constants.dart';

class BannerItem {
  const BannerItem({
    required this.imageUrl,
    this.tipoFiltro,
    this.valorFiltro,
  });

  final String imageUrl;
  final String? tipoFiltro;
  final String? valorFiltro;
}

class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key});

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;

  static const List<BannerItem> _banners = [
    // Valores de valorFiltro devem bater exatamente com a coluna
    // `categoria_menu` do banco (Combos, Sobremesas, Acompanhamento,
    // Prato Principal, Bebidas), senão a busca não retorna nada.
    BannerItem(
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800', // TODO: substituir por URL permanente (Firebase Storage ou asset local)
      tipoFiltro: 'categoria',
      valorFiltro: 'Prato Principal',
    ),
    BannerItem(
      imageUrl: 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=800',
      tipoFiltro: 'categoria',
      valorFiltro: 'Combos',
    ),
    BannerItem(
      imageUrl: 'https://images.unsplash.com/photo-1610348725531-843dff563e2c?w=800',
      tipoFiltro: 'categoria',
      valorFiltro: 'Bebidas',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= _banners.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180.h,
          child: GestureDetector(
            onPanDown: (_) => _timer?.cancel(),
            child: PageView.builder(
              controller: _pageController,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: _banners.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return GestureDetector(
                  onTap: () {
                    if (banner.tipoFiltro == 'categoria' && banner.valorFiltro != null) {
                      context.push('/search?categoria=${banner.valorFiltro}');
                    }
                  },
                  child: _BannerCard(banner: banner),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 12.h),
        _DotsIndicator(
          count: _banners.length,
          currentIndex: _currentPage,
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});
  final BannerItem banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: AppConstants.e2eMode
            ? Container(color: Colors.grey.shade200)
            : CachedNetworkImage(
          imageUrl: banner.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.currentIndex});
  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          width: isActive ? 20.w : 6.w,
          height: 6.h,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF5D201C)
                : const Color(0xFF5D201C).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3.r),
          ),
        );
      }),
    );
  }
}
