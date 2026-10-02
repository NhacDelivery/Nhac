/// O backend persiste o contexto em `conteudo`; REST e STOMP usam o mesmo texto.
class ProdutoChatReferencia {
  const ProdutoChatReferencia(
      {required this.nome,
      required this.id,
      required this.preco,
      this.imagem,
      this.mensagem = ''});
  final String nome, id, preco, mensagem;
  final String? imagem;

  static String _linha(String valor) =>
      valor.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  String serializar() =>
      [
        'Produto: ${_linha(nome)}',
        'ID: ${_linha(id)}',
        'Preço: ${_linha(preco)}',
        if (imagem?.isNotEmpty == true) 'Imagem: ${_linha(imagem!)}',
      ].join('\n') +
      (mensagem.isEmpty ? '' : '\n\n$mensagem');

  static ProdutoChatReferencia? ler(String conteudo) {
    final match = RegExp(
      r'^Produto: ([^\n]+)\nID: ([^\n]+)\nPreço: ([^\n]+)(?:\nImagem: ([^\n]+))?(?:\n\n([\s\S]*))?$',
    ).firstMatch(conteudo.replaceAll('\r\n', '\n'));
    if (match == null) return null;
    return ProdutoChatReferencia(
        nome: match[1]!,
        id: match[2]!,
        preco: match[3]!,
        imagem: match[4],
        mensagem: match[5] ?? '');
  }
}
