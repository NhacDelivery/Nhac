import 'package:nhac/pages/chat_conversa_page.dart';

/// Entrada de loja/pedido/produto; reutiliza o mesmo fluxo do chat direto.
class ChatLojaPage extends ChatConversaPage {
  const ChatLojaPage({
    super.key,
    required String lojaId,
    required String lojaNome,
    String? lojaFotoUrl,
    super.conversaId,
    super.heroTag,
    super.produtoReferencia,
    super.pedidoReferencia,
    super.repository,
    super.socket,
  }) : super(
          lojaId: lojaId,
          interlocutorNome: lojaNome,
          interlocutorFotoUrl: lojaFotoUrl,
        );
}
