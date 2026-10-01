import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/models/pedido/pedido_resumo_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class MeusPedidosPage extends StatefulWidget {
  const MeusPedidosPage({super.key, this.repository});
  final PedidoRepository? repository;

  @override
  State<MeusPedidosPage> createState() => _MeusPedidosPageState();
}

class _MeusPedidosPageState extends State<MeusPedidosPage> {
  static const _coral = Color(0xFFFF6961);
  static const _marrom = Color(0xFF5D201C);
  late final PedidoRepository _repository;
  final List<PedidoResumoModel> _pedidos = [];
  int _pagina = 0;
  bool _carregando = false;
  bool _temMais = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PedidoRepository();
    _carregar();
  }

  Future<void> _carregar({bool atualizar = false}) async {
    if (_carregando || (!atualizar && !_temMais)) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final pagina = atualizar ? 0 : _pagina;
    try {
      final novos = await _repository.buscarHistorico(page: pagina, size: 20);
      if (!mounted) return;
      setState(() {
        if (atualizar) _pedidos.clear();
        final ids = _pedidos.map((p) => p.id).toSet();
        _pedidos.addAll(novos.where((p) => ids.add(p.id)));
        _pagina = pagina + 1;
        _temMais = novos.length == 20;
      });
    } catch (_) {
      if (mounted)
        setState(() => _erro = 'Não foi possível carregar seus pedidos.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirPedido(PedidoResumoModel pedido) async {
    final path = pedido.status.terminal ? '/pedido-detalhes' : '/rastreio';
    await context.push('$path?pedidoId=${Uri.encodeQueryComponent(pedido.id)}');
    if (mounted) await _carregar(atualizar: true);
  }

  Widget _card(PedidoResumoModel pedido) {
    final entregue = pedido.status == StatusPedido.entregue;
    final cancelado = pedido.status == StatusPedido.cancelado;
    final cor = entregue
        ? Colors.green.shade700
        : cancelado
            ? Colors.grey.shade600
            : _coral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: ValueKey('pedido-${pedido.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrirPedido(pedido),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE7E5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: _coral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pedido.lojaNome,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _marrom,
                            ),
                          ),
                          if (pedido.criadoEm != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy • HH:mm')
                                  .format(pedido.criadoEm!.toLocal()),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        pedido.status.label,
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        NumberFormat.simpleCurrency(locale: 'pt_BR')
                            .format(pedido.valorTotal),
                        style: const TextStyle(
                          color: _marrom,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Color(0xFFFFE7E5)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pedido.status.terminal
                            ? 'Ver detalhes do pedido'
                            : 'Acompanhar pedido',
                        style: const TextStyle(
                          color: _coral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _coral),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFFE7E5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFE7E5),
          foregroundColor: _marrom,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Meus Pedidos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: RefreshIndicator(
          color: _coral,
          onRefresh: () => _carregar(atualizar: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Acompanhe seus pedidos e veja seu histórico.',
                style: TextStyle(color: _marrom),
              ),
              const SizedBox(height: 24),
              if (_pedidos.isEmpty && !_carregando && _erro == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          color: _coral, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Você ainda não fez pedidos',
                        style: TextStyle(
                          color: _marrom,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Seus pedidos aparecerão aqui.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ..._pedidos.map(_card),
              if (_erro != null) ...[
                Text(_erro!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _carregar,
                  child: const Text(
                    'Tentar novamente',
                    style: TextStyle(color: _coral),
                  ),
                ),
              ],
              if (_carregando)
                const Center(child: CircularProgressIndicator(color: _coral)),
              if (_temMais && !_carregando && _pedidos.isNotEmpty)
                TextButton(
                  onPressed: _carregar,
                  child: const Text(
                    'Carregar mais',
                    style: TextStyle(color: _coral),
                  ),
                ),
            ],
          ),
        ),
      );
}
