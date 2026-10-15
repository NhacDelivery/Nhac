import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nhac/components/estado_com_retry.dart';
import 'package:nhac/components/nhac_confirm_dialog.dart';
import 'package:nhac/models/pedido/operacao_pagamento_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/utils/error_ui_helper.dart';

/// Consulta independente: falha de pagamento não oculta o pedido já carregado.
class OperacaoPagamentoCard extends StatefulWidget {
  final String pedidoId;
  final PedidoRepository repository;
  final Future<void> Function()? aoCancelar;
  const OperacaoPagamentoCard({super.key, required this.pedidoId,
      required this.repository, this.aoCancelar});
  @override
  State<OperacaoPagamentoCard> createState() => _OperacaoPagamentoCardState();
}

class _OperacaoPagamentoCardState extends State<OperacaoPagamentoCard> with WidgetsBindingObserver {
  OperacaoPagamentoModel? _dados;
  String? _erro;
  bool _consultando = false;
  bool _enviando = false;
  bool _incerto = false;
  Timer? _timer;
  int _versao = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          _dados?.concluido != true) _carregar();
    });
  }
  @override
  void didUpdateWidget(OperacaoPagamentoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pedidoId != widget.pedidoId) {
      _versao++; _consultando = false; _enviando = false;
      _dados = null; _erro = null; _incerto = false; _carregar();
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ModalRoute.of(context)?.isCurrent == true) _carregar();
  }
  @override
  void dispose() {
    _versao++; _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose();
  }
  Future<void> _carregar() async {
    if (_consultando || _enviando) return;
    final versao = _versao;
    setState(() => _consultando = true);
    try {
      final dados = await widget.repository.buscarOperacaoPagamento(widget.pedidoId);
      if (!mounted || versao != _versao) return;
      setState(() { _dados = dados; _erro = null; _incerto = false; });
    } catch (_) {
      if (mounted && versao == _versao) setState(() => _erro = 'Não foi possível atualizar o pagamento.');
    } finally {
      if (mounted && versao == _versao) setState(() => _consultando = false);
    }
  }
  Future<void> _solicitar() async {
    if (_enviando || _consultando || _incerto || _dados?.podeSolicitarEstorno != true) return;
    final versao = _versao;
    // Inclui o diálogo no bloqueio para impedir duas confirmações simultâneas.
    setState(() => _enviando = true);
    final confirmou = await confirmarNhac(context, titulo: 'Cancelar e solicitar estorno?',
        mensagem: 'O pedido será cancelado e a devolução integral será solicitada. Você poderá acompanhar o estorno nos detalhes do pedido.',
        confirmar: 'Cancelar e solicitar estorno', cancelar: 'Manter pedido');
    if (!mounted || versao != _versao) return;
    if (!confirmou) { setState(() => _enviando = false); return; }
    try {
      await widget.repository.solicitarEstorno(widget.pedidoId);
    } catch (e) {
      if (!mounted || versao != _versao) return;
      setState(() { _enviando = false; _incerto = true;
        _erro = '${ErrorUIHelper.mensagem(e)} Atualize o acompanhamento antes de tentar novamente.'; });
      return;
    }
    if (!mounted || versao != _versao) return;
    setState(() { _enviando = false; _incerto = true; });
    await _carregar();
    // Falha da consulta após mutação não repete a mutação.
    if (mounted && versao == _versao) await widget.aoCancelar?.call();
  }
  @override
  Widget build(BuildContext context) {
    final dados = _dados;
    if (dados?.regular == true && dados?.podeSolicitarEstorno != true && _erro == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dados != null) ...[
            Row(children: [Icon(dados.concluido ? Icons.check_circle_outline : Icons.receipt_long_outlined),
              const SizedBox(width: 8), Expanded(child: Text(dados.titulo,
                style: Theme.of(context).textTheme.titleMedium))]),
            const SizedBox(height: 8), Text(dados.mensagem),
          ],
          if (dados == null && _consultando) const Text('Consultando o pagamento...'),
          if (_erro != null) BannerErroInline(mensagem: _erro!, aoTentarNovamente: _carregar),
          if (dados?.podeSolicitarEstorno == true) ...[
            const SizedBox(height: 12), OutlinedButton(
              onPressed: _enviando || _consultando || _incerto || _erro != null ? null : _solicitar,
              child: Text(_enviando ? 'Solicitando...' : 'Cancelar e solicitar estorno')),
          ],
          TextButton.icon(onPressed: _consultando || _enviando ? null : _carregar,
            icon: const Icon(Icons.refresh), label: Text(_consultando ? 'Atualizando...' : 'Atualizar pagamento')),
        ],
      )),
    );
  }
}
