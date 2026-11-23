import 'package:nhac/models/feed/feed_post_model.dart';

class FeedPerfilModel {
  const FeedPerfilModel({
    required this.id,
    required this.nome,
    this.avatarUrl,
    this.bannerUrl,
    this.anoCadastro,
    this.totalPublicacoes,
    this.lojaParaMensagem,
    required this.podeEnviarMensagem,
    required this.publicacoes,
    required this.temMais,
  });

  final String id;
  final String nome;
  final String? avatarUrl;
  final String? bannerUrl;
  final int? anoCadastro;
  final int? totalPublicacoes;
  final LojaParaMensagem? lojaParaMensagem;
  final bool podeEnviarMensagem;
  final List<FeedPostModel> publicacoes;
  final bool temMais;

  factory FeedPerfilModel.fromMap(Map<String, dynamic> map) {
    final loja = map['lojaParaMensagem'];
    return FeedPerfilModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      anoCadastro: (map['anoCadastro'] as num?)?.toInt(),
      totalPublicacoes: (map['totalPublicacoes'] as num?)?.toInt(),
      lojaParaMensagem: loja is Map<String, dynamic>
          ? LojaParaMensagem(
              id: loja['id'] as String,
              nome: loja['nome'] as String,
              imagemUrl: loja['imagemUrl'] as String?,
            )
          : null,
      podeEnviarMensagem: map['podeEnviarMensagem'] == true,
      publicacoes: (map['publicacoes'] as List)
          .map((post) => FeedPostModel.fromMap(Map<String, dynamic>.from(post)))
          .toList(),
      temMais: map['temMais'] == true,
    );
  }
}

class LojaParaMensagem {
  const LojaParaMensagem({
    required this.id,
    required this.nome,
    this.imagemUrl,
  });

  final String id;
  final String nome;
  final String? imagemUrl;
}
