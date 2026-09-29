import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/pedido/pedido_resumo_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class MeusPedidosPage extends StatefulWidget {
  const MeusPedidosPage({super.key});

  @override
  State<MeusPedidosPage> createState() => _MeusPedidosPageState();
}

class _MeusPedidosPageState extends State<MeusPedidosPage> {
  final PedidoRepository _repository = PedidoRepository();
  final List<PedidoResumoModel> _pedidos = [];
  int _pagina = 0;
  bool _carregando = false;
  bool _temMais = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_carregando || !_temMais) return;
    setState(() { _carregando = true; _erro = null; });
    try {
      final novos = await _repository.buscarHistorico(page: _pagina, size: 20);
      if (!mounted) return;
      setState(() {
        _pedidos.addAll(novos);
        _pagina++;
        _temMais = novos.length == 20;
      });
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar seus pedidos.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFE7E5),
    appBar: AppBar(title: const Text('Meus pedidos')),
    body: RefreshIndicator(
      onRefresh: () async {
        setState(() { _pedidos.clear(); _pagina = 0; _temMais = true; });
        await _carregar();
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_pedidos.isEmpty && !_carregando && _erro == null)
          const Padding(padding: EdgeInsets.all(24),
            child: Text('Seus pedidos aparecerão aqui.', textAlign: TextAlign.center)),
        for (final pedido in _pedidos)
          Card(child: ListTile(
            title: Text(pedido.lojaNome),
            subtitle: Text(pedido.status.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/rastreio?pedidoId=${pedido.id}'),
          )),
        if (_erro != null) ...[
          Text(_erro!, textAlign: TextAlign.center),
          TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
        ],
        if (_carregando) const Center(child: CircularProgressIndicator()),
        if (_temMais && !_carregando && _pedidos.isNotEmpty)
          TextButton(onPressed: _carregar, child: const Text('Carregar mais')),
      ]),
    ),
  );
}
