class FeedCommentModel {
  final String id;
  final String nome;
  final String? avatarUrl;
  final String conteudo;
  final bool isAuthor;
  final DateTime criadoEm;

  const FeedCommentModel({required this.id, required this.nome, this.avatarUrl,
    required this.conteudo, required this.isAuthor, required this.criadoEm});

  factory FeedCommentModel.fromMap(Map<String, dynamic> map) => FeedCommentModel(
    id: map['id'] as String,
    nome: map['nomeUsuario'] as String,
    avatarUrl: map['avatarUrl'] as String?,
    conteudo: map['conteudo'] as String,
    isAuthor: map['isAuthor'] == true,
    criadoEm: DateTime.parse(map['criadoEm'] as String),
  );
}
