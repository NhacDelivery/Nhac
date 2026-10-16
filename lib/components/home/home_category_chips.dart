import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/repositories/produto_repository.dart';

class HomeCategoryChips extends StatefulWidget {
  final ProdutoRepository? repository;
  const HomeCategoryChips({super.key, this.repository});
  @override
  State<HomeCategoryChips> createState() => _HomeCategoryChipsState();
}

class _HomeCategoryChipsState extends State<HomeCategoryChips> {
  late final ProdutoRepository _repository = widget.repository ?? ProdutoRepository();
  late Future<List<String>> _future = _repository.buscarCategorias();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _future,
    builder: (_, snapshot) {
      if (snapshot.hasError)
        return TextButton.icon(
          onPressed: () => setState(() {
            _future = _repository.buscarCategorias();
          }),
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar carregar categorias'),
        );
      final categorias = snapshot.data ?? [];
      if (categorias.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categorias.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
            label: Text(categorias[i]),
            avatar: const Icon(Icons.restaurant_menu, size: 18),
            onPressed: () => context.push(
              '/search?categoria=${Uri.encodeQueryComponent(categorias[i])}',
            ),
          ),
        ),
      );
    },
  );
}
