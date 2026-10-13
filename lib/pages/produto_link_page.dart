import 'package:flutter/material.dart';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/pages/produto_detalhes_page.dart';
import 'package:nhac/repositories/produto_repository.dart';

class ProdutoLinkPage extends StatefulWidget {
  final String produtoId;
  const ProdutoLinkPage({super.key, required this.produtoId});
  @override
  State<ProdutoLinkPage> createState() => _ProdutoLinkPageState();
}

class _ProdutoLinkPageState extends State<ProdutoLinkPage> {
  late Future<ProdutosModel> _produto;
  @override
  void initState() {
    super.initState();
    _produto = ProdutoRepository().buscarPorId(widget.produtoId);
  }

  @override
  void didUpdateWidget(covariant ProdutoLinkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.produtoId != widget.produtoId) {
      _produto = ProdutoRepository().buscarPorId(widget.produtoId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProdutosModel>(
    future: _produto,
    builder: (context, snapshot) {
      if (snapshot.hasData) return ProdutoDetalhesPage(produto: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: const Text('Produto compartilhado')),
        body: snapshot.hasError
            ? BannerErroInline(
                mensagem:
                    'Não foi possível abrir este produto. Ele pode não estar mais disponível.',
                aoTentarNovamente: () async {
                  setState(() {
                    _produto = ProdutoRepository().buscarPorId(
                      widget.produtoId,
                    );
                  });
                  try {
                    await _produto;
                  } catch (_) {}
                },
              )
            : const LoadingNhac(telaCheia: true),
      );
    },
  );
}
