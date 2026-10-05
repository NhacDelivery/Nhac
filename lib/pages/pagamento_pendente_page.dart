import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:nhac/components/nota_fiscal_pedido.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/globals/ui_utils.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/pagamento_pendente_model.dart';
import 'package:nhac/pages/qrcode_pix_page.dart';
import 'package:nhac/repositories/pedido_repository.dart';

/// Recupera sempre a cobrança existente; nenhuma credencial fica no dispositivo.
class PagamentoPendentePage extends StatefulWidget {
  final String pedidoId;
  const PagamentoPendentePage({super.key, required this.pedidoId});

  @override
  State<PagamentoPendentePage> createState() => _PagamentoPendentePageState();
}

class _PagamentoPendentePageState extends State<PagamentoPendentePage> {
  final PedidoRepository _repository = PedidoRepository();
  PagamentoPendenteModel? _pagamento;
  String? _erro;
  bool _carregando = true;
  bool _abrindoStripe = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final pagamento = await _repository.buscarPagamento(widget.pedidoId);
      if (!mounted) return;
      setState(() { _pagamento = pagamento; _carregando = false; });
    } catch (e) {
      try {
        final pedido = await _repository.buscarPedidoPorId(widget.pedidoId);
        if (!mounted) return;
        if (pedido.status.terminal) {
          context.go('/meus-pedidos');
          return;
        }
        if (pedido.status.pagamentoConfirmado) {
          await mostrarNotaFiscalEVerPedido(context, pedidoId: widget.pedidoId);
          return;
        }
      } catch (_) { /* A tela oferece nova tentativa. */ }
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e is AppException && e.code == 'PAGAMENTO_INDISPONIVEL'
              ? 'O prazo para pagar terminou. Acompanhe a atualização do pedido.'
              : 'Não foi possível recuperar este pagamento. Verifique a conexão e tente novamente.';
        });
      }
    }
  }

  Future<void> _pagarCartao() async {
    if (_abrindoStripe) return;
    if (!AppConstants.stripeConfigurado) {
      context.showError('Pagamento com cartão indisponível neste aparelho.');
      return;
    }
    setState(() => _abrindoStripe = true);
    try {
      final pagamentoAtual = await _repository.buscarPagamento(widget.pedidoId);
      final secret = pagamentoAtual.clientSecret;
      if (!mounted) return;
      if (secret == null || secret.isEmpty) {
        context.showError('O pagamento com cartão não está disponível.');
        return;
      }
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          merchantDisplayName: 'Nhac Delivery',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;
      final pedido = await _repository.buscarPedidoPorId(widget.pedidoId);
      if (!mounted) return;
      if (pedido.status.pagamentoConfirmado) {
        await mostrarNotaFiscalEVerPedido(context, pedidoId: widget.pedidoId);
      } else {
        context.showSuccess('Pagamento enviado. Aguardando confirmação.');
        context.go('/rastreio?pedidoId=${widget.pedidoId}');
      }
    } catch (_) {
      if (mounted) {
        context.showError(
            'Pagamento não confirmado. Você pode tentar novamente neste pedido até o prazo terminar.');
      }
    } finally {
      if (mounted) setState(() => _abrindoStripe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando || _erro != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagamento do pedido')),
        body: Center(child: _carregando
            ? const LoadingNhac(telaCheia: false)
            : Padding(padding: const EdgeInsets.all(24), child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_erro!, textAlign: TextAlign.center),
                  TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
                  TextButton(onPressed: () => context.go('/home-page'), child: const Text('Voltar ao início')),
                ],
              ))),
      );
    }
    final pagamento = _pagamento!;
    if (pagamento.formaPagamento == 'PIX') {
      return QrCodePixPage(
        pixQrCode: pagamento.qrCodeUrl ?? pagamento.pixCopiaECola ?? '',
        pixCopiaECola: pagamento.pixCopiaECola,
        paymentId: widget.pedidoId,
        valor: pagamento.valorTotal,
        expiraEm: pagamento.expiraEm,
        simulacaoDisponivel: pagamento.simulacaoDisponivel,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento com cartão')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.credit_card, color: Color(0xFFFF6961), size: 56),
          const SizedBox(height: 16),
          const Text('Seu pedido está aguardando pagamento.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (pagamento.expiraEm != null)
            Text('Pague até ${TimeOfDay.fromDateTime(pagamento.expiraEm!.toLocal()).format(context)}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _abrindoStripe ? null : _pagarCartao,
            child: Text(_abrindoStripe ? 'Abrindo pagamento...' : 'Pagar com cartão'),
          ),
          TextButton(
            onPressed: () => context.go('/rastreio?pedidoId=${widget.pedidoId}'),
            child: const Text('Acompanhar pedido'),
          ),
        ]),
      )),
    );
  }
}
