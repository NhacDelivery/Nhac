import 'package:nhac/utils/safe_parse_helpers.dart';

class ConversaPessoaResumo {
  final String id;
  final String pessoaId;
  final String pessoaNome;
  final String ultimaMensagem;
  final DateTime ultimaMensagemData;
  final int mensagensNaoLidas;

  ConversaPessoaResumo({
    required this.id,
    required this.pessoaId,
    required this.pessoaNome,
    required this.ultimaMensagem,
    required this.ultimaMensagemData,
    required this.mensagensNaoLidas,
  });

  factory ConversaPessoaResumo.fromMap(Map<String, dynamic> map) {
    final interlocutor = map['interlocutor'] is Map
        ? Map<String, dynamic>.from(map['interlocutor'] as Map)
        : const <String, dynamic>{};
    return ConversaPessoaResumo(
      id: map['id']?.toString() ?? map['conversaId']?.toString() ?? '',
      pessoaId:
          interlocutor['id']?.toString() ??
          map['pessoaId']?.toString() ??
          map['usuarioId']?.toString() ??
          '',
      pessoaNome:
          interlocutor['nome']?.toString() ??
          map['pessoaNome']?.toString() ??
          map['nome']?.toString() ??
          'Usuário',
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
