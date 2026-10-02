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
  final String pixQrCode;
  final String? pixCopiaECola;
  final String paymentId; // Este é o pedidoId retornado pelo backend
  final double valor;
  final DateTime? expiraEm;
  final bool simulacaoDisponivel;

  const QrCodePixPage({
    super.key,
    required this.pixQrCode,
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
  final PedidoRepository _pedidoRepository = PedidoRepository();
  final PedidoStatusSocketService _statusSocket = PedidoStatusSocketService();

  Timer? _pollingTimer;
  StreamSubscription<StatusPedido>? _statusSubscription;
  StatusPedido _statusPedido = StatusPedido.pendente;
  bool _timeout = false;
  bool _pagamentoConfirmado = false;
  bool _verificando = false;
  bool _simulando = false;
  int _tentativas = 0;
  static const int _maxTentativas =
      84; // Após sete minutos, manter consulta até estado terminal.
  static const Duration _intervaloPolling = Duration(seconds: 5);

  bool get _prazoVencido =>
      widget.expiraEm != null && !DateTime.now().isBefore(widget.expiraEm!);

  @override
  void initState() {
    super.initState();
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
    await _statusSocket.conectar(widget.paymentId);
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

  bool _mostrarBotaoVerificarManual = false;

  Future<void> _verificarStatus({bool manual = false}) async {
    if (_pagamentoConfirmado || !mounted || _verificando) return;
    _verificando = true;

    if (!manual) _tentativas++;

    try {
      final pedido =
          await _pedidoRepository.buscarPedidoPorId(widget.paymentId);
      if (!mounted) return;

      final status = pedido.status;

      setState(() {
        if (_tentativas >= 6) {
          _mostrarBotaoVerificarManual = true;
        }
      });

      await _aplicarStatus(status);

      if (status == StatusPedido.desconhecido) {
        if (mounted) {
          setState(() => _mostrarBotaoVerificarManual = true);
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar status do pedido: $e');
    } finally {
      _verificando = false;
    }

    // Após o prazo, continuar observando o backend enquanto a tela estiver aberta.
    if (_tentativas >= _maxTentativas && !_pagamentoConfirmado) {
      if (!mounted) return;
      setState(() {
        _timeout = true;
      });
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
    if (_pagamentoConfirmado) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 24.r),
            SizedBox(width: 8.w),
            Text(
              'Pagamento confirmado!',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (_timeout) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_off,
                    color: Colors.orange.shade700, size: 24.r),
                SizedBox(width: 8.w),
                Text(
                  'Tempo de verificacao esgotado',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Ainda não recebemos a confirmação. Vamos continuar verificando; você também pode acompanhar o pedido.',
              style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_statusPedido == StatusPedido.cancelado) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 24.r),
            SizedBox(width: 8.w),
            Text(
              _statusPedido.label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (_statusPedido == StatusPedido.desconhecido) {
      const realStatus = 'DESCONHECIDO';
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline,
                    color: Colors.blue.shade700, size: 24.r),
                SizedBox(width: 8.w),
                Text(
                  'Status: $realStatus',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'O status do pedido não foi reconhecido automaticamente. Por favor, acompanhe o andamento na tela de pedidos.',
              style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade800),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Aguardando pagamento — estado padrao com animacao
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE7E5),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24.r,
                height: 24.r,
                child: const LoadingNhac(telaCheia: false, tamanho: 24),
              ),
              SizedBox(width: 12.w),
              Text(
                'Aguardando pagamento...',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5D201C),
                ),
              ),
            ],
          ),
        ),
        if (_mostrarBotaoVerificarManual) ...[
          SizedBox(height: 16.h),
          TextButton.icon(
            onPressed: () {
              setState(() => _timeout = false);
              _verificarStatus(manual: true);
            },
            icon:
                Icon(Icons.refresh, color: const Color(0xFFFF6961), size: 20.r),
            label: Text(
              'Já paguei, verificar pedido',
              style: TextStyle(
                  color: const Color(0xFFFF6961), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  texto:
                      _timeout ? 'Voltar ao Inicio' : 'Aguardando pagamento...',
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
