class FeedCommentModel {
  final String id;
  final int curtidas;
  final bool curtido;
  final String? respostaAId;
  final String? respostaANome;
  final String nome;
  final String? usuarioId;
  final String? avatarUrl;
  final String conteudo;
  final bool isAuthor;
  final bool podeExcluir;
  final DateTime criadoEm;

  const FeedCommentModel({
    required this.id,
    this.curtidas = 0,
    this.curtido = false,
    this.respostaAId,
    this.respostaANome,
    required this.nome,
    this.usuarioId,
    this.avatarUrl,
    required this.conteudo,
    required this.isAuthor,
    this.podeExcluir = false,
    required this.criadoEm,
  });

  factory FeedCommentModel.fromMap(Map<String, dynamic> map) =>
      FeedCommentModel(
        id: map['id'] as String,
        curtidas: (map['curtidas'] as num? ?? 0).toInt(),
        curtido: map['curtido'] == true,
        respostaAId: map['respostaAId'] as String?,
        respostaANome: map['respostaANome'] as String?,
        nome: map['nomeUsuario'] as String,
        usuarioId: map['usuarioId'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
        conteudo: map['conteudo'] as String,
        isAuthor: map['isAuthor'] == true,
        podeExcluir: map['podeExcluir'] == true,
        criadoEm: DateTime.parse(map['criadoEm'] as String),
      );
}

/// Mantém a ordem dos tópicos do filtro e reúne cada resposta com seu pai.
/// Uma resposta cujo pai está em outra página aparece como tópico identificado.
List<({FeedCommentModel comentario, int nivel})> organizarComentarios(
    List<FeedCommentModel> comentarios) {
  final ids = comentarios.map((c) => c.id).toSet();
  final filhos = <String, List<FeedCommentModel>>{};
  final raizes = <FeedCommentModel>[];
  for (final c in comentarios) {
    final pai = c.respostaAId;
    if (pai != null && ids.contains(pai)) {
      (filhos[pai] ??= []).add(c);
    } else {
      raizes.add(c);
    }
  }
  final resultado = <({FeedCommentModel comentario, int nivel})>[];
  final visitados = <String>{};
  final pilha = [for (final raiz in raizes.reversed) (comentario: raiz, nivel: 0)];
  while (pilha.isNotEmpty) {
    final item = pilha.removeLast();
    if (!visitados.add(item.comentario.id)) continue;
    resultado.add(item);
    for (final filho in (filhos[item.comentario.id] ?? const <FeedCommentModel>[]).reversed) {
      pilha.add((comentario: filho, nivel: item.nivel + 1));
    }
  }
  return resultado;
}
