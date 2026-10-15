import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _azulNota = Color(0xFF0C2444);
const _prefixoNotaExibida = 'nota_fiscal_exibida_';


const Offset kOffsetLogo = Offset(6.50, 0.0);
const Offset kOffsetTextoTotal = Offset(1.0, 0.0);
const Offset kOffsetValorTotal = Offset(65.0, 0.0);
const Offset kOffsetLinhaTotal = Offset(0.0, 0.0);
const double kOffsetYCodigoBarras = -9.0;
const Offset kOffsetVolteSempre = Offset(8.0, -12.0);

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

  factory NotaFiscalDados.fromCarrinho({
    required String pedidoId,
    required Iterable<CartItemModel> itens,
    required double taxaFrete,
    required double desconto,
  }) {
    final snapshot = List<NotaFiscalItem>.unmodifiable(
      itens.map(
        (item) => NotaFiscalItem(
          nome: item.nome,
          preco: item.preco,
          quantidade: item.quantidade,
        ),
      ),
    );
    final subtotal = snapshot.fold<double>(
      0,
      (soma, item) => soma + item.subtotal,
    );
    return NotaFiscalDados(
      pedidoId: pedidoId,
      lojaNome: '',
      data: DateTime.now(),
      itens: snapshot,
      taxaFrete: taxaFrete,
      desconto: desconto,
      total: subtotal + taxaFrete - desconto,
    );
  }

  factory NotaFiscalDados.fromPedido(PedidoModel pedido) {
    final itens = pedido.itens
        .map(
          (i) => NotaFiscalItem(
            nome: i.adicionais.isEmpty
                ? i.nome
                : i.nome + '\n' + i.adicionais.join(' • '),
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
class NotaFiscalDialog extends StatefulWidget {
  const NotaFiscalDialog({
    super.key,
    required this.dados,
    this.aoConfirmar,
  });

  final NotaFiscalDados dados;
  final VoidCallback? aoConfirmar;

  @override
  State<NotaFiscalDialog> createState() => _NotaFiscalDialogState();
}

class _NotaFiscalDialogState extends State<NotaFiscalDialog>
    with TickerProviderStateMixin {
  // ── Animação de ENTRADA: desliza de cima para o centro ──
  late final AnimationController _entradaController;
  late final Animation<Offset> _slideEntrada;
  late final Animation<double> _fadeEntrada;

  // ── Animação de SAÍDA: desce girando na diagonal ──
  late final AnimationController _saidaController;
  late final Animation<Offset> _slideSaida;
  late final Animation<double> _rotacaoSaida;
  late final Animation<double> _fadeSaida;

  bool _saindo = false;

  @override
  void initState() {
    super.initState();

    // ── ENTRADA ──
    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Slide de cima (-1.2) até o centro (0), com curva suave
    _slideEntrada = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entradaController,
      curve: Curves.easeOutCubic,
    ));

    // Fade-in suave
    _fadeEntrada = CurvedAnimation(
      parent: _entradaController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // ── SAÍDA ──
    _saidaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Desce para baixo
    _slideSaida = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.15, 1.5),
    ).animate(CurvedAnimation(
      parent: _saidaController,
      curve: Curves.easeInCubic,
    ));

    // Rotação diagonal (de 0 a ~25 graus)
    _rotacaoSaida = Tween<double>(
      begin: 0,
      end: 0.44, // ~25 graus em radianos
    ).animate(CurvedAnimation(
      parent: _saidaController,
      curve: Curves.easeInCubic,
    ));

    // Fade-out na parte final da animação
    _fadeSaida = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _saidaController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    // Inicia a entrada
    _entradaController.forward();
  }

  @override
  void dispose() {
    _entradaController.dispose();
    _saidaController.dispose();
    super.dispose();
  }

  void _fechar() {
    if (_saindo) return;
    _saindo = true;

    // Dispara a subida da próxima tela aos 400ms enquanto a animação ainda está rodando
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        widget.aoConfirmar?.call();
      }
    });

    // Animação de descida e rotação (500ms)
    _saidaController.forward().then((_) {
      if (mounted) {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dados = widget.dados;
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
            // ── Papel da nota fiscal (com animação) ──
            AnimatedBuilder(
              animation: Listenable.merge([_entradaController, _saidaController]),
              builder: (context, child) {
                final offset = _saindo ? _slideSaida.value : _slideEntrada.value;
                final rotacao = _saindo ? _rotacaoSaida.value : 0.0;
                final opacidade = _saindo ? _fadeSaida.value : _fadeEntrada.value;

                return Transform.translate(
                  offset: Offset(
                    offset.dx * MediaQuery.of(context).size.width,
                    offset.dy * MediaQuery.of(context).size.height,
                  ),
                  child: Transform.rotate(
                    angle: rotacao,
                    alignment: Alignment.topRight,
                    child: Opacity(
                      opacity: opacidade.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
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
                    Transform.translate(
                      offset: kOffsetLogo,
                      child: Image.asset('assets/nhac-preto-branco.png', height: 60.h),
                    ),
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
                                  color: const Color.fromARGB(255, 94, 93, 93),
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
                    Transform.translate(
                      offset: kOffsetLinhaTotal,
                      child: Row(
                        children: [
                          Expanded(
                            child: Transform.translate(
                              offset: kOffsetTextoTotal,
                              child: Text(
                                'Total',
                                style: _estilo(20.sp, peso: FontWeight.w900),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Flexible(
                            child: Transform.translate(
                              offset: kOffsetValorTotal,
                              child: Text(
                                _moeda.format(dados.total),
                                textAlign: TextAlign.right,
                                style: _estilo(20.sp, peso: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Transform.translate(
                          offset: Offset(0.0, kOffsetYCodigoBarras),
                          child: SizedBox(
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
                        ),
                        Expanded(
                          child: Transform.translate(
                            offset: kOffsetVolteSempre,
                            child: Text(
                              'Volte sempre!',
                              textAlign: TextAlign.center,
                              style: _estilo(14.sp),
                            ),
                          ),
                        ),
                        SizedBox(width: 80.w),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── Botão fixo (sem animação) ──
            SizedBox(height: 20.h),
            BotaoLargoNhac(
              key: E2EKeys.checkoutSuccessContinue,
              texto: 'Ver pedido',
              onPressed: _fechar,
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
            flex: 5,
            child: Text(rotulo, style: _estilo(13.sp, peso: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
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
  bool acaoDisparada = false;
  void confirmarEAbrir() {
    if (acaoDisparada) return;
    acaoDisparada = true;
    _marcarExibida(pedidoId);
    if (context.mounted) abrirPedido();
  }

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => NotaFiscalDialog(
        dados: notaFinal,
        aoConfirmar: confirmarEAbrir,
      ),
    );
  } catch (_) {
    // Uma falha visual da nota nunca deve impedir o acesso ao pedido.
  }

  if (!context.mounted) return;
  confirmarEAbrir();
}

/// Exibe a nota fiscal com dados fictícios apenas para teste de animação.
/// Não navega para lugar nenhum ao fechar.
void mostrarNotaFiscalTeste(BuildContext context) {
  final dadosTeste = NotaFiscalDados(
    pedidoId: 'TESTE-12345678',
    lojaNome: 'Restaurante Exemplo',
    data: DateTime.now(),
    itens: const [
      NotaFiscalItem(nome: 'X-Burger Especial', preco: 28.90, quantidade: 2),
      NotaFiscalItem(nome: 'Batata Frita G', preco: 14.50, quantidade: 1),
      NotaFiscalItem(nome: 'Refrigerante 600ml', preco: 8.00, quantidade: 2),
    ],
    taxaFrete: 5.99,
    desconto: 10.00,
    total: 76.29,
  );

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => NotaFiscalDialog(dados: dadosTeste),
  );
}
