import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:nhac/services/home_order_route_observer.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/notificacao_historico_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:provider/provider.dart';

class HomeOrderTrackingCard extends StatefulWidget {
  const HomeOrderTrackingCard({
    super.key,
    this.isActive = true,
    this.initialPedido,
    this.pedidoRepository,
    this.socketService,
    this.onPedidoChanged,
  });

  final bool isActive;
  final PedidoModel? initialPedido;
  final PedidoRepository? pedidoRepository;
  final PedidoStatusSocketService? socketService;
  final ValueChanged<PedidoModel>? onPedidoChanged;

  @override
  State<HomeOrderTrackingCard> createState() => _HomeOrderTrackingCardState();
}

class _HomeOrderTrackingCardState extends State<HomeOrderTrackingCard>
    with SingleTickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  PedidoModel? _activePedido;
  bool _loading = true;
  String? _error;
  String? _usuarioId;
  String? _socketPedidoId;
  int? _tempoLojaMin;
  int? _tempoLojaMax;
  String? _tempoLojaPedidoId;
  late final PedidoRepository _repository;
  late final PedidoStatusSocketService _socket;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _fallbackTimer;
  bool _socketConectado = false;
  ConnectivityService? _connectivity;
  bool _wasOnline = true;
  bool _refreshing = false;
  bool _eventPending = false;
  Timer? _eventTimer;
  bool _visible = true;
  bool _foreground = true;
  bool get _active => widget.isActive && _visible && _foreground;
  int _generation = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _repository = widget.pedidoRepository ?? PedidoRepository();
    _socket = widget.socketService ?? PedidoStatusSocketService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _usuarioId = context.read<AuthService>().usuarioId;
    _statusSubscription = _socket.status.listen((novoStatus) async {
      if (!mounted || !_active) return;
      final pedido = _activePedido;
      if (pedido != null && pedido.status != novoStatus) {
        _generation++;
        _eventPending = _refreshing;
        _repository.invalidarPedido(pedido.id);
      }
      if (pedido != null && _usuarioId != null && pedido.status != novoStatus) {
        await NotificacaoHistoricoService.registrarStatus(
          _usuarioId!,
          pedido.id,
          novoStatus,
        );
      }
      if (widget.initialPedido == null &&
          novoStatus == StatusPedido.entregue &&
          _activePedido != null) {
        final pedidoId = _activePedido!.id;
        final visto = await LocalCacheService.isPedidoEntregueVisto(pedidoId);
        if (!visto && mounted && _active) {
          context.push('/pedido-entregue?pedidoId=$pedidoId');
        }
      }
      _loadActiveOrder();
    });
    _connectionSubscription = _socket.conectado.listen((connected) {
      _socketConectado = connected;
      if (connected) _loadActiveOrder();
    });
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.initialPedido == null &&
          _active &&
          _activePedido != null &&
          !_socketConectado) _loadActiveOrder();
    });
    _connectivity = context.read<ConnectivityService>();
    _wasOnline = _connectivity!.isOnline;
    _connectivity!.addListener(_onConnectivityChanged);
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialPedido != null) {
      _showOrder(widget.initialPedido!, persistir: false);
    } else {
      _restaurarEAtualizar();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) homeOrderRouteObserver.subscribe(this, route);
  }

  @override
  void didUpdateWidget(covariant HomeOrderTrackingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPedido != null &&
        widget.initialPedido != oldWidget.initialPedido) {
      _showOrder(widget.initialPedido!, persistir: false);
    }
    if (!_active) {
      _socketPedidoId = null;
      _socket.desconectar();
    } else if (!oldWidget.isActive) {
      if (_activePedido != null) _showOrder(_activePedido!, persistir: false);
      if (widget.initialPedido == null) _loadActiveOrder();
    }
  }

  @override
  void didPushNext() {
    _visible = false;
    _socketPedidoId = null;
    _socket.desconectar();
  }

  @override
  void didPopNext() {
    _visible = true;
    if (_activePedido != null) _showOrder(_activePedido!, persistir: false);
    if (widget.initialPedido == null) _loadActiveOrder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_active) {
      if (_activePedido != null) _showOrder(_activePedido!, persistir: false);
      if (widget.initialPedido == null) _loadActiveOrder();
    } else {
      _socketPedidoId = null;
      _socket.desconectar();
    }
  }

  void _onConnectivityChanged() {
    final online = _connectivity?.isOnline ?? false;
    if (online && !_wasOnline) _loadActiveOrder();
    _wasOnline = online;
  }

  Future<void> _restaurarEAtualizar() async {
    final usuarioId = _usuarioId;
    if (usuarioId != null) {
      final snapshot = await LocalCacheService.carregarSnapshotPedido(
        usuarioId,
      );
      if (mounted && snapshot != null && _usuarioId == usuarioId)
        _showOrder(snapshot, persistir: false);
    }
    if (mounted) _loadActiveOrder();
  }

  @override
  void dispose() {
    _generation++;
    homeOrderRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.removeListener(_onConnectivityChanged);
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _fallbackTimer?.cancel();
    _eventTimer?.cancel();
    _socket.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveOrder() async {
    if (_refreshing || !_active || !mounted) return;
    final usuarioId = context.read<AuthService>().usuarioId;
    if (usuarioId == null) return;
    if (_usuarioId != usuarioId) {
      _usuarioId = usuarioId;
      _activePedido = null;
      _socketPedidoId = null;
      await _socket.desconectar();
    }
    final generation = _generation;
    _refreshing = true;
    if (mounted)
      setState(() {
        _error = null;
        _loading = _activePedido == null;
      });
    try {
      final full = widget.initialPedido == null
          ? await _repository.buscarPedidoAtivo()
          : await _repository.buscarPedidoPorId(widget.initialPedido!.id);
      if (!mounted ||
          !_active ||
          generation != _generation ||
          context.read<AuthService>().usuarioId != usuarioId) return;
      final anterior = _activePedido;
      if (full != null &&
          (!full.status.terminal ||
              (anterior?.id == full.id && anterior?.status != full.status))) {
        await NotificacaoHistoricoService.registrarStatus(
          usuarioId,
          full.id,
          full.status,
        );
      } else if (full == null && anterior != null) {
        // /ativo pode deixar de devolver o pedido assim que ele é finalizado.
        try {
          final finalizado = await _repository.buscarPedidoPorId(anterior.id);
          if (mounted &&
              generation == _generation &&
              finalizado.status.terminal) {
            await NotificacaoHistoricoService.registrarStatus(
              usuarioId,
              finalizado.id,
              finalizado.status,
            );
          }
        } catch (_) {}
      }
      if (!mounted ||
          !_active ||
          generation != _generation ||
          context.read<AuthService>().usuarioId != usuarioId) return;
      if (full != null) widget.onPedidoChanged?.call(full);
      if (full != null && !full.status.terminal) {
        _showOrder(full);
        if (widget.initialPedido == null)
          await LocalCacheService.salvarPedidoAtivo(usuarioId, full.id);
      } else {
        if (widget.initialPedido == null &&
            full?.status == StatusPedido.entregue) {
          final visto = await LocalCacheService.isPedidoEntregueVisto(full!.id);
          if (!visto && mounted && _active) {
            context.push('/pedido-entregue?pedidoId=${full.id}');
          }
        }
        setState(() {
          _activePedido = null;
          _loading = false;
        });
        if (widget.initialPedido == null) {
          await LocalCacheService.removerPedidoAtivo(usuarioId);
          await LocalCacheService.removerSnapshotPedido(usuarioId);
        }
        _socketPedidoId = null;
        await _socket.desconectar();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível atualizar seu pedido.';
        });
      }
    } finally {
      _refreshing = false;
      if (_eventPending && mounted && _active) {
        _eventPending = false;
        _eventTimer?.cancel();
        _eventTimer =
            Timer(const Duration(milliseconds: 300), _loadActiveOrder);
      }
    }
  }

  void _showOrder(PedidoModel pedido, {bool persistir = true}) {
    setState(() {
      _activePedido = pedido;
      _loading = false;
      _error = null;
    });
    final usuarioId = _usuarioId;
    if (usuarioId != null && persistir && widget.initialPedido == null)
      LocalCacheService.salvarSnapshotPedido(usuarioId, pedido);
    if (_active && _socketPedidoId != pedido.id) {
      _socketPedidoId = pedido.id;
      _socket.desconectar().then((_) {
        if (!mounted || !_active || _socketPedidoId != pedido.id) return;
        _socket.conectar(pedido.id);
      });
    }
    if (_tempoLojaPedidoId == pedido.id) return;
    _tempoLojaPedidoId = pedido.id;
    _tempoLojaMin = null;
    _tempoLojaMax = null;
    LojaRepository().buscarLoja(pedido.lojaId).then((loja) {
      if (!mounted || _activePedido?.id != pedido.id) return;
      setState(() {
        _tempoLojaMin = loja?.dadosOperacionais?.tempoEntregaMin;
        _tempoLojaMax = loja?.dadosOperacionais?.tempoEntregaMax;
      });
    }).catchError((_) {});
  }

  String _estimativa(StatusPedido status) {
    switch (status) {
      case StatusPedido.pendente:
        return 'Aguardando pagamento';
      case StatusPedido.pago:
      case StatusPedido.preparando:
      case StatusPedido.saiuEntrega:
        if (_tempoLojaMin != null && _tempoLojaMax != null) {
          return 'Estimativa geral da loja: $_tempoLojaMin–$_tempoLojaMax min';
        }
        return 'Acompanhe o andamento do pedido';
      default:
        return '';
    }
  }

  IconData _statusIcon(StatusPedido status) {
    switch (status) {
      case StatusPedido.pendente:
        return Icons.payment_rounded;
      case StatusPedido.pago:
        return Icons.check_circle_outline_rounded;
      case StatusPedido.preparando:
        return Icons.restaurant_rounded;
      case StatusPedido.saiuEntrega:
        return Icons.delivery_dining_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activePedido == null) {
      if (_loading || _error == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu pedido',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6961),
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _loadActiveOrder,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final pedido = _activePedido!;
    final stage = pedido.status.stage;
    const totalStages = 4;
    final progress = stage / totalStages;

    final imageUrl =
        pedido.itens.isNotEmpty ? pedido.itens.first.imagemUrl : '';

    final pagamentoPendente = pedido.status == StatusPedido.pendente &&
        (pedido.formaPagamento.toUpperCase() == 'PIX' ||
            pedido.formaPagamento.toUpperCase() == 'CARTAO' ||
            pedido.formaPagamento.toUpperCase() == 'STRIPE' ||
            pedido.formaPagamento.toUpperCase() == 'GOOGLE_PAY');
    return Semantics(
      button: true,
      label: pagamentoPendente
          ? 'Continuar pagamento do pedido'
          : 'Acompanhar pedido',
      child: GestureDetector(
        onTap: () => context.push(
          pagamentoPendente
              ? '/pagamento?pedidoId=${pedido.id}'
              : '/rastreio?pedidoId=${pedido.id}',
        ),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadActiveOrder,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ],
                if (pagamentoPendente)
                  Text(
                    'Toque para continuar o pagamento',
                    style: TextStyle(
                      color: const Color(0xFF5D201C),
                      fontSize: 13.sp,
                    ),
                  ),
                // ── Header row: icon + status + arrow ──
                Row(
                  children: [
                    // Animated pulse icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7E5).withValues(
                              alpha: 0.5 + _pulseController.value * 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            _statusIcon(pedido.status),
                            color: const Color(0xFFFE645C),
                            size: 22.r,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusTexto(pedido),
                            style: TextStyle(
                              color: const Color(0xFF5D201C),
                              fontWeight: FontWeight.bold,
                              fontSize: 15.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _estimativa(pedido.status),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.grey.shade400,
                        size: 14.r,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14.h),

                // Product thumbnail and name
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 48.w,
                              height: 48.w,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 48.w,
                                height: 48.w,
                                color: const Color(0xFFFFE7E5),
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  color: const Color(0xFFFE645C),
                                  size: 20.r,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 48.w,
                                height: 48.w,
                                color: const Color(0xFFFFE7E5),
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  color: const Color(0xFFFE645C),
                                  size: 20.r,
                                ),
                              ),
                            )
                          : Container(
                              width: 48.w,
                              height: 48.w,
                              color: const Color(0xFFFFE7E5),
                              child: Icon(
                                Icons.fastfood_rounded,
                                color: const Color(0xFFFE645C),
                                size: 20.r,
                              ),
                            ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        pedido.itens.isNotEmpty
                            ? pedido.itens.first.nome
                            : pedido.lojaNome,
                        style: TextStyle(
                          color: const Color(0xFF5D201C),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (pedido.entregador != null) ...[
                  SizedBox(height: 10.h),
                  _buildEntregadorCard(pedido.entregador!),
                ],

                SizedBox(height: 14.h),

                // ── Progress bar ──
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0, end: progress),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 6.h,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFE645C),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // ── Stage labels ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStageLabel('Pago', stage >= 1),
                        _buildStageLabel('Preparo', stage >= 2),
                        _buildStageLabel('A caminho', stage >= 3),
                        _buildStageLabel('Entregue', stage >= 4),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageLabel(String label, bool active) {
    return Text(
      label,
      style: TextStyle(
        color: active ? const Color(0xFFFE645C) : Colors.grey.shade400,
        fontSize: 10.sp,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  String _statusTexto(PedidoModel pedido) {
    if (pedido.entregador != null) {
      if (pedido.status == StatusPedido.preparando) {
        return '${pedido.entregador!.nome} aceitou sua entrega';
      }
      if (pedido.status == StatusPedido.saiuEntrega) {
        return '${pedido.entregador!.nome} está a caminho';
      }
    }
    return pedido.status.label;
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
      key: const Key('cartao-entregador-home'),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0ED),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: const Color(0xFFFF6961).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: entregador.fotoUrl != null && entregador.fotoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: entregador.fotoUrl!,
                    width: 36.r,
                    height: 36.r,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 36.r,
                      height: 36.r,
                      color: const Color(0xFFFFE7E5),
                      child: Icon(
                        Icons.two_wheeler,
                        color: const Color(0xFFFE645C),
                        size: 18.r,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 36.r,
                      height: 36.r,
                      color: const Color(0xFFFFE7E5),
                      child: Icon(
                        Icons.two_wheeler,
                        color: const Color(0xFFFE645C),
                        size: 18.r,
                      ),
                    ),
                  )
                : Container(
                    width: 36.r,
                    height: 36.r,
                    color: const Color(0xFFFFE7E5),
                    child: Icon(
                      Icons.two_wheeler,
                      color: const Color(0xFFFE645C),
                      size: 18.r,
                    ),
                  ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entregador.nome,
                        style: TextStyle(
                          color: const Color(0xFF5D201C),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (temAvaliacao) ...[
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber.shade700,
                        size: 15.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${entregador.avaliacaoMedia?.toStringAsFixed(1) ?? "5.0"} (${entregador.totalAvaliacoes})',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (infoVeiculo.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    infoVeiculo,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
