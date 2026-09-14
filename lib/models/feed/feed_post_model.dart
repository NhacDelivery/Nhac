class TopCommentModel {
  final String nomeUsuario;
  final String conteudo;
  final int curtidas;

  const TopCommentModel({
    required this.nomeUsuario,
    required this.conteudo,
    required this.curtidas,
  });
}

class FeedPostModel {
  final String id;
  final String nomeUsuario;
  final String? avatarUrl;
  final String? badge;
  final String? dispositivo;
  final String conteudo;
  final List<String> imagens;
  final int curtidas;
  final int comentarios;
  final List<String> hashTags;
  final bool isPatrocinado;
  final String? sponsorLabel;
  final TopCommentModel? topComment;

  const FeedPostModel({
    required this.id,
    required this.nomeUsuario,
    this.avatarUrl,
    this.badge,
    this.dispositivo,
    required this.conteudo,
    this.imagens = const [],
    required this.curtidas,
    required this.comentarios,
    this.hashTags = const [],
    this.isPatrocinado = false,
    this.sponsorLabel,
    this.topComment,
  });
}
