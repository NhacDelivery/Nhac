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
    return ConversaPessoaResumo(
      id: map['id']?.toString() ?? map['conversaId']?.toString() ?? '',
      pessoaId:
          map['pessoaId']?.toString() ?? map['usuarioId']?.toString() ?? '',
      pessoaNome:
          map['pessoaNome']?.toString() ?? map['nome']?.toString() ?? 'Usuário',
      ultimaMensagem: map['ultimaMensagem']?.toString() ?? '',
      ultimaMensagemData:
          DateTime.tryParse(map['ultimaMensagemData']?.toString() ?? '') ??
          DateTime.now(),
      mensagensNaoLidas: safeInt(map['mensagensNaoLidas']),
    );
  }
}
