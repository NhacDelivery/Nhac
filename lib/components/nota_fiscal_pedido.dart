import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _azulNota = Color(0xFF0C2444);
const _prefixoNotaExibida = 'nota_fiscal_exibida_';

class NotaFiscalItem {
  const NotaFiscalItem({
    required this.nome,
    required this.preco,
    required this.quantidade,
  });

  final String nome;
  final double preco;
  final int quantidade;

  double get subtotal => preco * quantidade;
}

class NotaFiscalDados {
  const NotaFiscalDados({
    required this.pedidoId,
    required this.lojaNome,
    required this.data,
    required this.itens,
    required this.taxaFrete,
    required this.desconto,
    required this.total,
  });

  final String pedidoId;
  final String lojaNome;
  final DateTime data;
  final List<NotaFiscalItem> itens;
  final double taxaFrete;
  final double desconto;
  final double total;

  double get subtotal => itens.fold(0, (soma, item) => soma + item.subtotal);

  factory NotaFiscalDados.fromPedido(PedidoModel pedido) {
    final itens = pedido.itens
        .map(
          (i) => NotaFiscalItem(
            nome: i.nome,
            preco: i.preco,
            quantidade: i.quantidade,
          ),
        )
        .toList();
    final subtotal = itens.fold<double>(0, (soma, i) => soma + i.subtotal);

    final desconto = subtotal + pedido.taxaFrete - pedido.valorTotal;
    return NotaFiscalDados(
      pedidoId: pedido.id,
      lojaNome: pedido.lojaNome,
      data: (pedido.criadoEm ?? DateTime.now()).toLocal(),
      itens: itens,
      taxaFrete: pedido.taxaFrete,
      desconto: desconto > 0.009 ? desconto : 0,
      total: pedido.valorTotal,
    );
  }
}

final NumberFormat _moeda = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
);

TextStyle _estilo(double tamanho, {FontWeight peso = FontWeight.bold}) =>
    TextStyle(fontSize: tamanho, fontWeight: peso, color: _azulNota);

/// Nota fiscal (cupom) do pedido, exibida antes de abrir o acompanhamento.
class NotaFiscalDialog extends StatelessWidget {
  const NotaFiscalDialog({super.key, required this.dados});

  final NotaFiscalDados dados;

  @override
  Widget build(BuildContext context) {
    final dataFormatada = DateFormat(
      'EEEE - d MMM. yyyy - HH:mm',
      'pt_BR',
    ).format(dados.data);
    final idCurto = dados.pedidoId.length > 8
        ? dados.pedidoId.substring(0, 8)
        : dados.pedidoId;

    return Dialog(
      key: E2EKeys.checkoutSuccess,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      elevation: 0,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/nota-fiscal.png'),
                  fit: BoxFit.fill,
                ),
              ),
              padding: EdgeInsets.fromLTRB(24.w, 35.h, 24.w, 35.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/nhac-preto-branco.png', height: 60.h),
                  SizedBox(height: 8.h),
                  Text(
                    dados.lojaNome.isEmpty ? 'Nhac Delivery' : dados.lojaNome,
                    textAlign: TextAlign.center,
                    style: _estilo(16.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(dataFormatada, style: _estilo(12.sp)),
                  SizedBox(height: 24.h),
                  for (final item in dados.itens)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(item.nome, style: _estilo(14.sp)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${_moeda.format(item.preco)} x ${item.quantidade}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _moeda.format(item.subtotal),
                              textAlign: TextAlign.right,
                              style: _estilo(14.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16.h),
                  const _LinhaPontilhada(),
                  SizedBox(height: 12.h),
                  _LinhaValor(
                    rotulo: 'Taxa de entrega',
                    valor: _moeda.format(dados.taxaFrete),
                  ),
                  if (dados.desconto > 0)
                    _LinhaValor(
                      rotulo: 'Desconto do cupom',
                      valor: '- ${_moeda.format(dados.desconto)}',
                    ),
                  SizedBox(height: 12.h),
                  const _LinhaPontilhada(),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: _estilo(20.sp, peso: FontWeight.w900),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Flexible(
                        child: Text(
                          _moeda.format(dados.total),
                          textAlign: TextAlign.right,
                          style: _estilo(20.sp, peso: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      SizedBox(
                        height: 30.h,
                        width: 80.w,
                        child: Semantics(
                          key: E2EKeys.checkoutSuccessOrderId,
                          value: dados.pedidoId,
                          child: BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: idCurto,
                            drawText: false,
                            color: _azulNota,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Volte sempre!',
                          textAlign: TextAlign.center,
                          style: _estilo(14.sp),
                        ),
                      ),
                      SizedBox(width: 80.w),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            BotaoLargoNhac(
              key: E2EKeys.checkoutSuccessContinue,
              texto: 'Ver pedido',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaValor extends StatelessWidget {
  const _LinhaValor({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: _estilo(13.sp, peso: FontWeight.w600),
            ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: _estilo(13.sp, peso: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaPontilhada extends StatelessWidget {
  const _LinhaPontilhada();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          (constraints.constrainWidth() / 8).floor(),
          (_) => const SizedBox(
            width: 4,
            height: 2,
            child: DecoratedBox(decoration: BoxDecoration(color: _azulNota)),
          ),
        ),
      ),
    );
  }
}

Future<bool> _jaExibida(String pedidoId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefixoNotaExibida$pedidoId') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _marcarExibida(String pedidoId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefixoNotaExibida$pedidoId', true);
  } catch (_) {}
}

Future<void> mostrarNotaFiscalEVerPedido(
  BuildContext context, {
  required String pedidoId,
  NotaFiscalDados? dadosLocais,
  VoidCallback? aoConcluir,
  PedidoRepository? repository,
}) async {
  final router = GoRouter.of(context);
  final destino = '/rastreio?pedidoId=${Uri.encodeQueryComponent(pedidoId)}';

  void abrirPedido() {
    aoConcluir?.call();
    router.go(destino);
  }

  if (await _jaExibida(pedidoId)) {
    if (context.mounted) abrirPedido();
    return;
  }

  NotaFiscalDados? dados = dadosLocais;
  try {
    final pedido = await (repository ?? PedidoRepository()).buscarPedidoPorId(
      pedidoId,
    );
    dados = NotaFiscalDados.fromPedido(pedido);
  } catch (_) {
    // Usa o snapshot local, se houver.
  }

  if (!context.mounted) return;
  if (dados == null) {
    abrirPedido();
    return;
  }

  final notaFinal = dados;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => NotaFiscalDialog(dados: notaFinal),
    );
  } catch (_) {
    // Uma falha visual da nota nunca deve impedir o acesso ao pedido.
  }

  if (!context.mounted) return;
  await _marcarExibida(pedidoId);
  if (context.mounted) abrirPedido();
}
