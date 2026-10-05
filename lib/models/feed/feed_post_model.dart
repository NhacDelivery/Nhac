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

class MentionedStoreModel {
  final String? id;
  final String nome;
  final String imageUrl;
  final double rating;
  final String avaliacoes;

  const MentionedStoreModel({
    this.id,
    required this.nome,
    required this.imageUrl,
    required this.rating,
    required this.avaliacoes,
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
  final int salvos;
  final bool curtido;
  final bool salvo;
  final List<String> hashTags;
  final bool isPatrocinado;
  final String? sponsorLabel;
  final TopCommentModel? topComment;
  final MentionedStoreModel? mentionedStore;

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
    this.salvos = 0,
    this.curtido = false,
    this.salvo = false,
    this.hashTags = const [],
    this.isPatrocinado = false,
    this.sponsorLabel,
    this.topComment,
    this.mentionedStore,
  });

  factory FeedPostModel.fromMap(Map<String, dynamic> map) {
    final store = map['mentionedStore'] as Map?;
    return FeedPostModel(
      id: map['id'] as String,
      nomeUsuario: map['nomeUsuario'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      conteudo: map['conteudo'] as String,
      imagens: List<String>.from(map['imagens'] as List? ?? const []),
      hashTags: List<String>.from(map['hashTags'] as List? ?? const []),
      curtidas: (map['curtidas'] as num).toInt(),
      comentarios: (map['comentarios'] as num).toInt(),
      salvos: (map['salvos'] as num? ?? 0).toInt(),
      curtido: map['curtido'] == true,
      salvo: map['salvo'] == true,
      isPatrocinado: map['isPatrocinado'] == true,
      sponsorLabel: map['sponsorLabel'] as String?,
      mentionedStore: store == null ? null : MentionedStoreModel(
        id: store['id'] as String?,
        nome: store['nome'] as String,
        imageUrl: store['imageUrl'] as String? ?? '',
        rating: (store['rating'] as num? ?? 0).toDouble(),
        avaliacoes: store['avaliacoes'] as String? ?? '0 avaliações',
      ),
    );
  }

}
