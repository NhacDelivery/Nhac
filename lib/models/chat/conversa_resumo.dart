import 'package:nhac/utils/safe_parse_helpers.dart';

class ConversaResumo {
  final String id;
  final String lojaId;
  final String lojaNome;
  final String? lojaFotoUrl;
  final String ultimaMensagem;
  final DateTime ultimaMensagemData;
  final int mensagensNaoLidas;

  ConversaResumo({
    required this.id,
    required this.lojaId,
    required this.lojaNome,
    this.lojaFotoUrl,
    required this.ultimaMensagem,
    required this.ultimaMensagemData,
    required this.mensagensNaoLidas,
  });

  factory ConversaResumo.fromMap(Map<String, dynamic> map) {
    final interlocutor = map['interlocutor'] is Map
        ? Map<String, dynamic>.from(map['interlocutor'] as Map)
        : const <String, dynamic>{};
    return ConversaResumo(
      id: map['id']?.toString() ?? map['conversaId']?.toString() ?? '',
      lojaId: interlocutor['id']?.toString() ?? map['lojaId']?.toString() ?? '',
      lojaNome:
          interlocutor['nome']?.toString() ??
          map['lojaNome']?.toString() ??
          map['nomeLoja']?.toString() ??
          map['nome']?.toString() ??
          'Loja',
      lojaFotoUrl:
          interlocutor['imagemUrl']?.toString() ??
          interlocutor['imagem']?.toString() ??
          interlocutor['foto']?.toString() ??
          interlocutor['logo']?.toString() ??
          map['lojaImagemUrl']?.toString() ??
          map['imagemUrl']?.toString() ??
          map['foto']?.toString(),
      ultimaMensagem:
          map['ultimaMensagemPreview']?.toString() ??
          map['ultimaMensagem']?.toString() ??
          '',
      ultimaMensagemData:
          DateTime.tryParse(
            (map['ultimaMensagemEm'] ?? map['ultimaMensagemData'])
                    ?.toString() ??
                '',
          )?.toLocal() ??
          DateTime.now(),
      mensagensNaoLidas: safeInt(map['naoLidas'] ?? map['mensagensNaoLidas']),
    );
  }
}
