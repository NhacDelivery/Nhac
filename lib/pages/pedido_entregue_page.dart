import 'package:nhac/pages/avaliar_produto_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:nhac/components/pedido/avaliacao_entregador_sheet.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/live_notification_service.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:provider/provider.dart';

class PedidoEntreguePage extends StatefulWidget {
  final String pedidoId;
  final PedidoRepository? pedidoRepository;
  final PedidoModel? initialPedido;

  const PedidoEntreguePage({
    super.key,
    required this.pedidoId,
    this.pedidoRepository,
    this.initialPedido,
  });

  @override
  State<PedidoEntreguePage> createState() => _PedidoEntreguePageState();
}

class _PedidoEntreguePageState extends State<PedidoEntreguePage> {
  late final PedidoRepository _repository;
  PedidoModel? _pedido;
  bool _loading = true;
  String? _erro;
  bool _entregadorAvaliado = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.pedidoRepository ?? PedidoRepository();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    String? usuarioId;
    try {
      usuarioId = context.read<AuthService?>()?.usuarioId;
    } catch (_) {}

    if (!AppConstants.e2eMode) {
      LiveNotificationService.cancelLiveNotification(pedidoId: widget.pedidoId);
    }
    await LocalCacheService.marcarPedidoEntregueVisto(widget.pedidoId);
    // Abrir um pedido antigo não deve apagar o pedido atual da conta.
    if (usuarioId != null &&
        await LocalCacheService.carregarPedidoAtivo(usuarioId) ==
            widget.pedidoId) {
      await LocalCacheService.removerPedidoAtivo(usuarioId);
      await LocalCacheService.removerSnapshotPedido(usuarioId);
    }

    // 3. Inicializa ou carrega o pedido
    if (widget.initialPedido != null) {
      if (mounted) {
        setState(() {
          _pedido = widget.initialPedido;
          _entregadorAvaliado = widget.initialPedido!.entregadorAvaliado;
          _loading = false;
        });
      }
      return;
    }

    await _carregarPedido();
  }

  Future<void> _carregarPedido() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final pedido = await _repository.buscarPedidoPorId(widget.pedidoId);
      bool avaliado = pedido.entregadorAvaliado;

      if (pedido.status == StatusPedido.entregue &&
          !avaliado &&
          pedido.entregador != null) {
        try {
          final avaliacao = await _repository.buscarAvaliacaoEntregador(
            widget.pedidoId,
          );
          if (avaliacao != null) {
            avaliado = true;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _entregadorAvaliado = avaliado;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os detalhes do pedido.';
        _loading = false;
      });
    }
  }

  void _abrirAvaliacao() {
    if (_pedido?.status != StatusPedido.entregue) return;
    final entregador = _pedido?.entregador;
    AvaliacaoEntregadorSheet.show(
      context,
      pedidoId: widget.pedidoId,
      entregadorNome: entregador?.nome,
      pedidoRepository: _repository,
      onAvaliado: () {
        if (mounted) {
          setState(() {
            _entregadorAvaliado = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: LoadingNhac(telaCheia: false)));
    }

    if (_erro != null || _pedido == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade400,
                  size: 56.sp,
                ),
                SizedBox(height: 16.h),
                Text(
                  _erro ?? 'Pedido não encontrado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: const Color(0xFF5D201C),
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: _carregarPedido,
                  child: const Text('Tentar novamente'),
                ),
                TextButton(
                  onPressed: () => context.go('/home-page'),
                  child: const Text('Voltar ao início'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pedido = _pedido!;
    final entregue = pedido.status == StatusPedido.entregue;
    final cancelado = pedido.status == StatusPedido.cancelado;
    final entregador = pedido.entregador;
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final horarioPedido = pedido.criadoEm == null
        ? 'Não informado'
        : DateFormat('dd/MM/yyyy • HH:mm').format(pedido.criadoEm!.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE7E5),
        foregroundColor: const Color(0xFF5D201C),
        surfaceTintColor: Colors.transparent,
        title: const Text('Detalhes do pedido'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16.h),
              // Ícone de sucesso animado/destaque
              Center(
                child: Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    color: entregue
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFE7E5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    entregue
                        ? Icons.check_circle_rounded
                        : cancelado
                        ? Icons.cancel_outlined
                        : Icons.receipt_long_rounded,
                    color: entregue
                        ? Colors.green.shade600
                        : const Color(0xFFFF6961),
                    size: 52.r,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                entregue ? 'Pedido entregue!' : pedido.status.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D201C),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                entregue
                    ? 'Esperamos que você aproveite sua refeição.'
                    : cancelado
                    ? 'Este pedido foi finalizado e não será entregue.'
                    : 'Confira o resumo do seu pedido.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
              ),
              SizedBox(height: 24.h),

              // Card de detalhes principais (Loja, Total, Horário)
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restaurante',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                pedido.lojaNome,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF5D201C),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              currencyFormat.format(pedido.valorTotal),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6961),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Divider(height: 24.h, color: Colors.grey.shade200),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data do pedido',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          horarioPedido,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5D201C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Resumo de Itens
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo dos itens',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D201C),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    if (pedido.itens.isEmpty)
                      Text(
                        'Itens do pedido entregue',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      ...pedido.itens.map(
                        (item) => Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Row(
                            children: [
                              Text(
                                '${item.quantidade}x',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF6961),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  item.nome,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey.shade800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              if (entregue) ...[
                for (final item in {
                  for (final item in pedido.itens) item.produtoId: item,
                }.values)
                  TextButton.icon(
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text('Avaliar ${item.nome}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AvaliarProdutoPage(
                          produtoId: item.produtoId,
                          pedidoId: pedido.id,
                          nome: item.nome,
                        ),
                      ),
                    ),
                  ),
              ],
              // Card do Entregador (se houver)
              if (entregador != null) ...[
                _buildEntregadorCard(entregador),
                SizedBox(height: 24.h),
              ] else ...[
                SizedBox(height: 16.h),
              ],

              // Botão Avaliar Entregador (apenas se entregador != null e !entregadorAvaliado)
              if (entregue && entregador != null && !_entregadorAvaliado) ...[
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton.icon(
                    key: const Key('botao-avaliar-entregador'),
                    onPressed: _abrirAvaliacao,
                    icon: Icon(
                      Icons.star_rounded,
                      color: Colors.amber.shade300,
                      size: 22.sp,
                    ),
                    label: Text(
                      'Avaliar entregador',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6961),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],

              // Botão Voltar ao Início
              SizedBox(
                height: 48.h,
                child: OutlinedButton(
                  key: const Key('botao-voltar-inicio'),
                  onPressed: () => context.go('/home-page'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5D201C),
                    side: const BorderSide(
                      color: Color(0xFF5D201C),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.r),
                    ),
                  ),
                  child: Text(
                    'Voltar ao início',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntregadorCard(EntregadorPedidoModel entregador) {
    final infoVeiculo = [
      if (entregador.modeloVeiculo != null &&
          entregador.modeloVeiculo!.isNotEmpty)
        entregador.modeloVeiculo,
      if (entregador.corVeiculo != null && entregador.corVeiculo!.isNotEmpty)
        entregador.corVeiculo,
      if (entregador.placaVeiculo != null &&
          entregador.placaVeiculo!.isNotEmpty)
        '(${entregador.placaVeiculo})',
    ].join(' · ');

    final temAvaliacao = (entregador.totalAvaliacoes ?? 0) > 0;

    return Container(
      key: const Key('cartao-entregador-entregue'),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22.r),
                child:
                    entregador.fotoUrl != null && entregador.fotoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: entregador.fotoUrl!,
                        width: 44.r,
                        height: 44.r,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 44.r,
                          height: 44.r,
                          color: const Color(0xFFFFE7E5),
                          child: Icon(
                            Icons.two_wheeler,
                            color: const Color(0xFFFF6961),
                            size: 22.r,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 44.r,
                          height: 44.r,
                          color: const Color(0xFFFFE7E5),
                          child: Icon(
                            Icons.two_wheeler,
                            color: const Color(0xFFFF6961),
                            size: 22.r,
                          ),
                        ),
                      )
                    : Container(
                        width: 44.r,
                        height: 44.r,
                        color: const Color(0xFFFFE7E5),
                        child: Icon(
                          Icons.two_wheeler,
                          color: const Color(0xFFFF6961),
                          size: 22.r,
                        ),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entregador',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      entregador.nome,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D201C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (infoVeiculo.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        infoVeiculo,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (temAvaliacao) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.amber.shade700,
                      size: 16.sp,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      '${entregador.avaliacaoMedia?.toStringAsFixed(1) ?? "5.0"} (${entregador.totalAvaliacoes})',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (_entregadorAvaliado) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    size: 14.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Entregador já avaliado',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
