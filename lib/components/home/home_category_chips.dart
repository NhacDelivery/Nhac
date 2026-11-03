import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/repositories/produto_repository.dart';

class HomeCategoryChips extends StatefulWidget {
  final ProdutoRepository? repository;
  const HomeCategoryChips({super.key, this.repository});
  @override
  State<HomeCategoryChips> createState() => _HomeCategoryChipsState();
}

class _HomeCategoryChipsState extends State<HomeCategoryChips> {
  late final ProdutoRepository _repository =
      widget.repository ?? ProdutoRepository();
  late Future<List<String>> _future = _repository.buscarCategorias();

  IconData _iconeParaCategoria(String categoria) {
    final lower = categoria.toLowerCase().trim();
    if (lower.contains('bebid')) return Icons.local_drink_rounded;
    if (lower.contains('pizza')) return Icons.local_pizza_rounded;
    if (lower.contains('lanch') || lower.contains('hamburg')) {
      return Icons.lunch_dining_rounded;
    }
    if (lower.contains('doce') || lower.contains('sobremes')) {
      return Icons.cake_rounded;
    }
    if (lower.contains('salgad')) return Icons.fastfood_rounded;
    if (lower.contains('acomp')) return Icons.restaurant_rounded;
    if (lower.contains('padar') ||
        lower.contains('pão') ||
        lower.contains('pao')) {
      return Icons.bakery_dining_rounded;
    }
    if (lower.contains('japon') ||
        lower.contains('sushi') ||
        lower.contains('orient')) {
      return Icons.ramen_dining_rounded;
    }
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
        future: _future,
        builder: (_, snapshot) {
          if (snapshot.hasError) {
            return TextButton.icon(
              onPressed: () => setState(() {
                _future = _repository.buscarCategorias();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar carregar categorias'),
            );
          }
          final categorias = snapshot.data ?? [];
          if (categorias.isEmpty) {
            return const SizedBox.shrink();
          }
          return SizedBox(
            height: 52.h,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, __) => SizedBox(width: 10.w),
              itemBuilder: (_, i) => ActionChip(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 1,
                pressElevation: 2,
                shadowColor: const Color(0xFF5D201C).withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
                side: const BorderSide(
                  color: Color(0xFFFFE7E5),
                  width: 1.0,
                ),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                label: Text(categorias[i]),
                labelStyle: TextStyle(
                  color: const Color(0xFF5D201C),
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
                avatar: Icon(
                  _iconeParaCategoria(categorias[i]),
                  size: 20.r,
                  color: const Color(0xFFFF6961),
                ),
                onPressed: () => context.push(
                  '/search?categoria=${Uri.encodeQueryComponent(categorias[i])}',
                ),
              ),
            ),
          );
        },
      );
}
