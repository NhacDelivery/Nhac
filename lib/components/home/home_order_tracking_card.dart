import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:nhac/services/home_order_route_observer.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:provider/provider.dart';

class HomeOrderTrackingCard extends StatefulWidget {
  const HomeOrderTrackingCard({super.key, this.isActive = true});

  final bool isActive;

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
  final PedidoRepository _repository = PedidoRepository();
  final PedidoStatusSocketService _socket = PedidoStatusSocketService();
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _fallbackTimer;
  bool _socketConectado = false;
  ConnectivityService? _connectivity;
  bool _wasOnline = true;
  bool _refreshing = false;
  bool _refreshPending = false;
  int _generation = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _usuarioId = context.read<AuthService>().usuarioId;
    _statusSubscription = _socket.status.listen((_) => _loadActiveOrder());
    _connectionSubscription = _socket.conectado.listen((connected) {
      _socketConectado = connected;
      if (connected) _loadActiveOrder();
    });
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.isActive && _activePedido != null && !_socketConectado) _loadActiveOrder();
    });
    _connectivity = context.read<ConnectivityService>();
    _wasOnline = _connectivity!.isOnline;
    _connectivity!.addListener(_onConnectivityChanged);
    WidgetsBinding.instance.addObserver(this);
    _restaurarEAtualizar();
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
    if (widget.isActive && !oldWidget.isActive) _loadActiveOrder();
  }

  @override
  void didPopNext() => _loadActiveOrder();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) _loadActiveOrder();
  }

  void _onConnectivityChanged() {
    final online = _connectivity?.isOnline ?? false;
    if (online && !_wasOnline) _loadActiveOrder();
    _wasOnline = online;
  }

  Future<void> _restaurarEAtualizar() async {
    final usuarioId = _usuarioId;
    if (usuarioId != null) {
      final snapshot = await LocalCacheService.carregarSnapshotPedido(usuarioId);
      if (mounted && snapshot != null && _usuarioId == usuarioId) _showOrder(snapshot, persistir: false);
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
    _socket.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveOrder() async {
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
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
    if (mounted) setState(() { _error = null; _loading = _activePedido == null; });
    try {
      final full = await _repository.buscarPedidoAtivo();
      if (!mounted || generation != _generation) return;
      if (full != null && !full.status.terminal) {
        _showOrder(full);
        await LocalCacheService.salvarPedidoAtivo(usuarioId, full.id);
      } else {
        setState(() { _activePedido = null; _loading = false; });
        await LocalCacheService.removerPedidoAtivo(usuarioId);
        await LocalCacheService.removerSnapshotPedido(usuarioId);
        _socketPedidoId = null;
        await _socket.desconectar();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _loading = false; _error = 'Não foi possível atualizar seu pedido.'; });
      }
    } finally {
      _refreshing = false;
      if (_refreshPending && mounted) {
        _refreshPending = false;
        _loadActiveOrder();
      }
    }
  }

  void _showOrder(PedidoModel pedido, {bool persistir = true}) {
    setState(() { _activePedido = pedido; _loading = false; _error = null; });
    final usuarioId = _usuarioId;
    if (usuarioId != null && persistir) LocalCacheService.salvarSnapshotPedido(usuarioId, pedido);
    if (_socketPedidoId != pedido.id) {
      _socketPedidoId = pedido.id;
      _socket.desconectar().then((_) {
        if (!mounted || _socketPedidoId != pedido.id) return;
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
      if (!_loading && _error == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Card(child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Seu pedido', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _loadActiveOrder, child: const Text('Tentar novamente')),
            ],
          ]),
        )),
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
      label: pagamentoPendente ? 'Continuar pagamento do pedido' : 'Acompanhar pedido',
      child: GestureDetector(
      onTap: () => context.push(pagamentoPendente
          ? '/pagamento?pedidoId=${pedido.id}'
          : '/rastreio?pedidoId=${pedido.id}'),
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
                Row(children: [
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  TextButton(onPressed: _loadActiveOrder, child: const Text('Tentar novamente')),
                ]),
              ],
              if (pagamentoPendente)
                Text('Toque para continuar o pagamento',
                    style: TextStyle(color: const Color(0xFF5D201C), fontSize: 13.sp)),
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
                              alpha: 0.5 + _pulseController.value * 0.5),
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
                          pedido.status.label,
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
                              Color(0xFFFE645C)),
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
    ));
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
}
