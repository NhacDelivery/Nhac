import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:nhac/components/nota_fiscal_pedido.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';

class QrCodePixPage extends StatefulWidget {
  final PedidoRepository? pedidoRepository;
  final PedidoStatusSocketService? statusSocket;
  final String pixQrCode;
  final String? pixCopiaECola;
  final String paymentId; // Este é o pedidoId retornado pelo backend
  final double valor;
  final DateTime? expiraEm;
  final bool simulacaoDisponivel;

  const QrCodePixPage({
    super.key,
    required this.pixQrCode,
    this.pedidoRepository,
    this.statusSocket,
    this.pixCopiaECola,
    required this.paymentId,
    required this.valor,
    this.expiraEm,
    this.simulacaoDisponivel = false,
  });

  @override
  State<QrCodePixPage> createState() => _QrCodePixPageState();
}

class _QrCodePixPageState extends State<QrCodePixPage> {
  late final PedidoRepository _pedidoRepository;
  late final PedidoStatusSocketService _statusSocket;
  String? _erroVerificacao;

  Timer? _pollingTimer;
  StreamSubscription<StatusPedido>? _statusSubscription;
  StatusPedido _statusPedido = StatusPedido.pendente;
  bool _timeout = false;
  bool _pagamentoConfirmado = false;
  bool _verificando = false;
  bool _simulando = false;
  int _tentativas = 0;
  static const int _maxTentativas =
      84; // Após sete minutos, encerrar polling e manter a consulta manual.
  static const Duration _intervaloPolling = Duration(seconds: 5);

  bool get _prazoVencido =>
      widget.expiraEm != null && !DateTime.now().isBefore(widget.expiraEm!);

  @override
  void initState() {
    super.initState();
    _pedidoRepository = widget.pedidoRepository ?? PedidoRepository();
    _statusSocket = widget.statusSocket ?? PedidoStatusSocketService();
    _iniciarPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarStatus());
    _conectarStatus();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _statusSubscription?.cancel();
    _statusSocket.dispose();
    super.dispose();
  }

  Future<void> _conectarStatus() async {
    _statusSubscription = _statusSocket.status.listen(_aplicarStatus);
    try {
      await _statusSocket.conectar(widget.paymentId);
    } catch (_) {
      // A consulta HTTP permanece disponível quando o socket falha.
    }
  }

  Future<void> _aplicarStatus(StatusPedido status) async {
    if (!mounted || _pagamentoConfirmado) return;

    setState(() => _statusPedido = status);

    if (status.pagamentoConfirmado) {
      _pollingTimer?.cancel();
      setState(() => _pagamentoConfirmado = true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) await _navegarParaRastreio(sucesso: true);
    } else if (status == StatusPedido.cancelado) {
      _pollingTimer?.cancel();
      if (mounted) {
        context.showError('O prazo terminou. O pedido está no histórico.');
        context.go('/meus-pedidos');
      }
    }
  }

  void _iniciarPolling() {
    _pollingTimer =
        Timer.periodic(_intervaloPolling, (_) => _verificarStatus());
  }

  Future<void> _verificarStatus({bool manual = false}) async {
    if (_pagamentoConfirmado || !mounted || _verificando) return;
    setState(() => _verificando = true);
    if (!manual) _tentativas++;
    try {
      _pedidoRepository.invalidarPedido(widget.paymentId);
      final pedido =
          await _pedidoRepository.buscarPedidoPorId(widget.paymentId);
      if (!mounted) return;
      setState(() => _erroVerificacao = null);
      await _aplicarStatus(pedido.status);
    } catch (_) {
      if (mounted && !_pagamentoConfirmado) {
        setState(() => _erroVerificacao =
            'Não foi possível consultar o pagamento. Confira sua conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
    if (_tentativas >= _maxTentativas && !_pagamentoConfirmado) {
      _pollingTimer?.cancel();
      if (mounted) setState(() => _timeout = true);
    }
  }

  bool _abrindoPedido = false;

  Future<void> _navegarParaRastreio({bool sucesso = false}) async {
    if (sucesso) {
      if (_abrindoPedido) return;
      _abrindoPedido = true;
      context.showSuccess(
          'Pagamento PIX confirmado! Acompanhe o andamento do pedido.');
      try {
        await mostrarNotaFiscalEVerPedido(
          context,
          pedidoId: widget.paymentId,
        );
      } finally {
        if (mounted) _abrindoPedido = false;
      }
      return;
    }
    context.go(
      '/rastreio?pedidoId=${Uri.encodeQueryComponent(widget.paymentId)}',
    );
  }

  Future<void> _simularPagamento() async {
    if (_simulando || !widget.simulacaoDisponivel) return;
    setState(() => _simulando = true);
    try {
      await _pedidoRepository.simularPagamentoPix(widget.paymentId);
      if (mounted) await _verificarStatus(manual: true);
    } catch (_) {
      if (mounted) {
        context.showError(
          'Não foi possível confirmar o teste. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _simulando = false);
    }
  }

  Widget _buildStatusIndicator() {
    final String titulo;
    final String? detalhe;
    final IconData icone;
    if (_pagamentoConfirmado) {
      titulo = 'Pagamento confirmado!';
      detalhe = null;
      icone = Icons.check_circle;
    } else if (_erroVerificacao != null) {
      titulo = 'Pagamento ainda não verificado';
      detalhe = _erroVerificacao;
      icone = Icons.wifi_off;
    } else if (_timeout) {
      titulo = 'Verificação automática encerrada';
      detalhe =
          'Ainda não recebemos a confirmação. Consulte novamente ou acompanhe o pedido.';
      icone = Icons.timer_off;
    } else {
      titulo = _statusPedido == StatusPedido.desconhecido
          ? 'Status do pagamento indisponível'
          : 'Aguardando pagamento...';
      detalhe = null;
      icone = Icons.hourglass_empty;
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _pagamentoConfirmado
              ? Colors.green.shade50
              : const Color(0xFFFFE7E5),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (_verificando && !_pagamentoConfirmado)
              SizedBox.square(
                  dimension: 24.r,
                  child: const LoadingNhac(telaCheia: false, tamanho: 24))
            else
              Icon(icone, size: 24.r, color: const Color(0xFF5D201C)),
            SizedBox(width: 12.w),
            Expanded(
                child: Text(titulo,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5D201C)))),
          ]),
          if (detalhe != null) ...[
            SizedBox(height: 8.h),
            Text(detalhe, textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento PIX'),
        backgroundColor: const Color(0xFFFF6961),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              SizedBox(height: 32.h),
              // Titulo
              Text(
                'Escaneie o QR Code',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D201C),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Use seu app de banco para escanear e pagar',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.expiraEm != null) ...[
                SizedBox(height: 8.h),
                Text(
                    'Pague até ${TimeOfDay.fromDateTime(widget.expiraEm!.toLocal()).format(context)}',
                    style: TextStyle(
                        fontSize: 13.sp, color: const Color(0xFF5D201C))),
              ],
              if (_prazoVencido)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'O prazo terminou. Estamos conferindo o estado do pedido.',
                      textAlign: TextAlign.center),
                ),
              SizedBox(height: 24.h),
              // Indicador de status do pagamento
              _buildStatusIndicator(),
              if (!_pagamentoConfirmado)
                TextButton.icon(
                  onPressed: _verificando
                      ? null
                      : () => _verificarStatus(manual: true),
                  icon: const Icon(Icons.refresh),
                  label: Text(_verificando
                      ? 'Verificando pedido...'
                      : 'Já paguei, verificar pedido'),
                ),
              SizedBox(height: 24.h),
              // QR Code
              Semantics(
                label:
                    'QR Code PIX. Valor de R\$ ${widget.valor.toStringAsFixed(2)}',
                image: true,
                child: AnimatedOpacity(
                  opacity: _pagamentoConfirmado || _prazoVencido ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: widget.pixQrCode,
                      version: QrVersions.auto,
                      size: 250.w,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              // Valor
              MergeSemantics(
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7E5),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Valor a pagar:',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'R\$ ${widget.valor.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 48.h),
              // Botao principal — muda conforme o status
              if (_pagamentoConfirmado)
                BotaoLargoNhac(
                  texto: 'Ver pedido',
                  onPressed: () => _navegarParaRastreio(sucesso: true),
                )
              else
                BotaoLargoNhac(
                  texto: _timeout
                      ? 'Acompanhar pedido'
                      : 'Aguardando pagamento...',
                  onPressed: _timeout ? () => _navegarParaRastreio() : null,
                ),
              SizedBox(height: 16.h),
              OutlinedButton(
                onPressed: _prazoVencido
                    ? null
                    : () {
                        final textToCopy =
                            widget.pixCopiaECola ?? widget.pixQrCode;
                        Clipboard.setData(ClipboardData(text: textToCopy));

                        context.showSuccess('Codigo PIX copiado!');
                      },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  'Copiar codigo PIX',
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(height: 16.h),
              if (widget.simulacaoDisponivel &&
                  !_pagamentoConfirmado &&
                  !_prazoVencido)
                TextButton(
                  onPressed: _simulando ? null : _simularPagamento,
                  child: Text(_simulando
                      ? 'Confirmando...'
                      : 'Simular pagamento (teste)'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
