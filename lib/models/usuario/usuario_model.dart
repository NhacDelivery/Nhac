
class UsuarioModel {
  final String id;
  final String nome;
  final String email;
  final String telefone;
  final String? imagemUrl;
  final String? senha;

  UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.telefone,
    this.imagemUrl,
    this.senha,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      telefone: map['telefone']?.toString() ?? '',
      imagemUrl: map['imagemUrl']?.toString(),
      // 'senha' nunca vem do backend nas respostas (nunca é serializada
      // de volta), então não há o que ler aqui — só existe no toMap()
      // para o payload de criação.
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      if (imagemUrl != null) 'imagemUrl': imagemUrl,
      if (senha != null) 'senha': senha,
    };
  }
}
