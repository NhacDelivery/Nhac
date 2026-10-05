class FeedCommentModel {
  final String id;
  final String nome;
  final String? usuarioId;
  final String? avatarUrl;
  final String conteudo;
  final bool isAuthor;
  final bool podeExcluir;
  final DateTime criadoEm;

  const FeedCommentModel({
    required this.id,
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
        nome: map['nomeUsuario'] as String,
        usuarioId: map['usuarioId'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
        conteudo: map['conteudo'] as String,
        isAuthor: map['isAuthor'] == true,
        podeExcluir: map['podeExcluir'] == true,
        criadoEm: DateTime.parse(map['criadoEm'] as String),
      );
}
