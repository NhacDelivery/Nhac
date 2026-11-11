import 'package:nhac/models/produto/produtos.dart';

/// Seções derivadas do catálogo, sem destruir o conjunto usado como fallback.
class HomeProductSelection {
  final List<ProdutosModel> principais;
  final List<ProdutosModel> secundarios;
  final String tituloSecundario;
  HomeProductSelection._(
      this.principais, this.secundarios, this.tituloSecundario);

  factory HomeProductSelection.from(
      List<ProdutosModel> catalogo, List<ProdutosModel> promocoes) {
    final porId = <String, ProdutosModel>{};
    for (final p in [...catalogo, ...promocoes]) {
      if (p.id.isNotEmpty) porId.putIfAbsent(p.id, () => p);
    }
    final todos = porId.values.toList();
    // Partição estável: lojas abertas primeiro, sem embaralhar a cada resposta.
    List<ProdutosModel> priorizar(Iterable<ProdutosModel> itens) => [
          ...itens.where((p) => p.lojaAberta),
          ...itens.where((p) => !p.lojaAberta),
        ];
    final ordenados = priorizar(todos);
    final economicos = priorizar(todos.where((p) => p.preco < 20));
    return HomeProductSelection._(
      ordenados.take(10).toList(),
      (economicos.isEmpty ? ordenados : economicos).take(10).toList(),
      economicos.isEmpty ? 'Explore o cardápio' : 'Tudo abaixo de R\$ 20',
    );
  }
}
