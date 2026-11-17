import 'package:nhac/models/feed/feed_post_model.dart';

class FeedPerfilModel {
  const FeedPerfilModel({
    required this.id,
    required this.nome,
    this.avatarUrl,
    this.bannerUrl,
    required this.podeEnviarMensagem,
    required this.publicacoes,
    required this.temMais,
  });

  final String id;
  final String nome;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool podeEnviarMensagem;
  final List<FeedPostModel> publicacoes;
  final bool temMais;

  factory FeedPerfilModel.fromMap(Map<String, dynamic> map) {
    return FeedPerfilModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      podeEnviarMensagem: map['podeEnviarMensagem'] == true,
      publicacoes: (map['publicacoes'] as List)
          .map((post) => FeedPostModel.fromMap(Map<String, dynamic>.from(post)))
          .toList(),
      temMais: map['temMais'] == true,
    );
  }
}
