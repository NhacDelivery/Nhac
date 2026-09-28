import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class HomeCategoryChips extends StatelessWidget {
  const HomeCategoryChips({super.key});

  // Valores devem bater exatamente com a coluna `categoria_menu` do banco,
  // já que o backend filtra produtos/lojas por valor exato.
  static const _categorias = [
    {'nome': 'Combos', 'icon': Icons.fastfood},
    {'nome': 'Pratos Executivos', 'icon': Icons.restaurant},
    {'nome': 'Acompanhamentos', 'icon': Icons.rice_bowl},
    {'nome': 'Sobremesas', 'icon': Icons.icecream},
    {'nome': 'Bebidas', 'icon': Icons.local_drink},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categorias.length,
        itemBuilder: (context, index) {
          final cat = _categorias[index];
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ActionChip(
              label: Text(cat['nome'] as String),
              avatar: Icon(cat['icon'] as IconData, size: 16.r),
              onPressed: () {
                context.push('/search?categoria=${Uri.encodeComponent(cat['nome'] as String)}');
              },
            ),
          );
        },
      ),
    );
  }
}
