import 'package:nhac/utils/safe_parse_helpers.dart';

class ConversaResumo {
  final String id;
  final String lojaId;
  final String lojaNome;
  final String ultimaMensagem;
  final DateTime ultimaMensagemData;
  final int mensagensNaoLidas;

  ConversaResumo({
    required this.id,
    required this.lojaId,
    required this.lojaNome,
    required this.ultimaMensagem,
    required this.ultimaMensagemData,
    required this.mensagensNaoLidas,
  });

  factory ConversaResumo.fromMap(Map<String, dynamic> map) {
    return ConversaResumo(
      id: map['id']?.toString() ?? map['conversaId']?.toString() ?? '',
      lojaId: map['lojaId']?.toString() ?? '',
      lojaNome: map['lojaNome']?.toString() ?? map['nomeLoja']?.toString() ?? map['nome']?.toString() ?? 'Loja',
      ultimaMensagem: map['ultimaMensagem']?.toString() ?? '',
      ultimaMensagemData: DateTime.tryParse(map['ultimaMensagemData']?.toString() ?? '') ?? DateTime.now(),
      mensagensNaoLidas: safeInt(map['mensagensNaoLidas']),
    );
  }
}
