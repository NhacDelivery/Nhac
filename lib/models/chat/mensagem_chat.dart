// lib/models/chat/mensagem_chat.dart
//
// Espelha o ChatDTOs.MensagemDTO do backend. O mesmo formato chega por dois
// caminhos: pelo histórico REST (GET /conversas/{id}/mensagens) e pelo frame
// STOMP em /topic/conversas/{id}.

class MensagemChat {
  final String id;
  final String conversaId;

  /// 'CLIENTE' ou 'LOJA'. Do lado do app, CLIENTE é sempre o próprio usuário.
  final String remetenteTipo;
  final String? remetenteUsuarioId;
  final String conteudo;
  final DateTime enviadaEm;

  const MensagemChat({
    required this.id,
    required this.conversaId,
    required this.remetenteTipo,
    required this.conteudo,
    required this.enviadaEm,
    this.remetenteUsuarioId,
  });

  bool get isDoCliente => remetenteTipo == 'CLIENTE';

  factory MensagemChat.fromMap(Map<String, dynamic> map) {
    return MensagemChat(
      id: (map['id'] ?? '').toString(),
      conversaId: (map['conversaId'] ?? '').toString(),
      remetenteTipo: (map['remetenteTipo'] ?? 'LOJA').toString(),
      remetenteUsuarioId: map['remetenteUsuarioId']?.toString(),
      conteudo: (map['conteudo'] ?? '').toString(),
      // enviadaEm vem como Instant serializado em ISO-8601 (UTC).
      enviadaEm: DateTime.tryParse(map['enviadaEm']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MensagemChat && other.id == id && id.isNotEmpty;

  @override
  int get hashCode => id.hashCode;
}
