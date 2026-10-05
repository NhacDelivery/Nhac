import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nhac/components/home/home_order_tracking_card.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/home_order_route_observer.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeOrders extends StatefulWidget {
  const HomeOrders(
      {super.key, required this.isActive, this.repository, this.socketFactory});
  final bool isActive;
  final PedidoRepository? repository;
  final PedidoStatusSocketService Function(String pedidoId)? socketFactory;
  @override
  State<HomeOrders> createState() => HomeOrdersState();
}

class HomeOrdersState extends State<HomeOrders>
    with RouteAware, WidgetsBindingObserver {
  late final _repository = widget.repository ?? PedidoRepository();
  List<PedidoModel> _orders = [];
  Timer? _timer;
  bool _pending = false;
  bool _visible = true;
  bool _foreground = true;
  String? _error;
  int _generation = 0;
  final _orderRevisions = <String, int>{};
  String? _user;
  bool get _active => widget.isActive && _visible && _foreground;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthService>().usuarioId;
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  Future<void> _restore() async {
    final user = _user;
    final generation = _generation;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted ||
        generation != _generation ||
        context.read<AuthService>().usuarioId != user) return;
    try {
      final raw = prefs.getString('pedidos_home_$_user');
      if (raw != null) {
        final data = jsonDecode(raw) as Map;
        if (DateTime.now().difference(DateTime.parse(data['saved'] as String)) <
            LocalCacheService.retencaoHome) {
          final orders = (data['orders'] as List)
              .map((e) =>
                  PedidoModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .where((p) => p.usuarioId == _user && !p.status.terminal)
              .toList();
          if (mounted) setState(() => _orders = orders);
        }
      } else {
        final legacy =
            await LocalCacheService.carregarSnapshotPedido(_user ?? '');
        if (mounted &&
            generation == _generation &&
            context.read<AuthService>().usuarioId == user &&
            legacy != null) setState(() => _orders = [legacy]);
      }
    } catch (_) {
      // Um snapshot inválido não equivale a uma resposta vazia do servidor.
    }
    if (mounted) await refresh();
  }

  Future<void> refresh() async {
    if (!mounted || !_active || _pending) return;
    final user = context.read<AuthService>().usuarioId;
    if (user != _user) {
      _generation++;
      _user = user;
      _orderRevisions.clear();
      setState(() => _orders = []);
    }
    if (user == null) return;
    final generation = _generation;
    final revisions = Map<String, int>.of(_orderRevisions);
    setState(() => _pending = true);
    try {
      final orders = await _repository.buscarPedidosAtivos();
      if (!mounted ||
          !_active ||
          generation != _generation ||
          context.read<AuthService>().usuarioId != user) return;
      setState(() {
        final incoming = {for (final order in orders) order.id: order};
        // Uma atualização individual mais recente prevalece sobre a lista em voo.
        for (final id in _orderRevisions.keys) {
          if (_orderRevisions[id] != revisions[id]) {
            if (!_orders.any((p) => p.id == id)) incoming.remove(id);
            for (final known in _orders.where((p) => p.id == id)) {
              incoming[id] = known;
            }
          }
        }
        _orders = incoming.values
            .where((p) => p.usuarioId == user && !p.status.terminal)
            .toList();
        _error = null;
      });
      await _persistSnapshot();
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _error = 'Não foi possível atualizar os pedidos.');
    } finally {
      if (mounted && generation == _generation)
        setState(() => _pending = false);
    }
  }

  void _orderChanged(PedidoModel order) {
    if (!mounted || order.usuarioId != _user) return;
    _orderRevisions.update(order.id, (value) => value + 1, ifAbsent: () => 1);
    setState(() {
      _orders = [
        for (final known in _orders)
          if (known.id != order.id) known else if (!order.status.terminal) order
      ];
    });
    _persistSnapshot();
  }

  Future<void> _persistSnapshot() async {
    final user = _user;
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          user == null ||
          generation != _generation ||
          context.read<AuthService>().usuarioId != user) return;
      await prefs.setString(
          'pedidos_home_$user',
          jsonEncode({
            'saved': DateTime.now().toUtc().toIso8601String(),
            'orders':
                _orders.map((p) => p.toMap()..remove('codigoEntrega')).toList(),
          }));
    } catch (_) {
      // A falha do cache local não transforma uma resposta válida em falha HTTP.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) homeOrderRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => setState(() => _visible = false);
  @override
  void didPopNext() {
    setState(() => _visible = true);
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (_foreground) refresh();
  }

  @override
  void didUpdateWidget(HomeOrders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) refresh();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    homeOrderRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_orders.isEmpty && _error == null) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: Text(_error!)),
            TextButton(
                onPressed: refresh, child: const Text('Tentar novamente')),
          ]),
        ),
      if (_pending && _orders.isNotEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Color(0xFFFF6961))),
        ),
      for (final order in _orders)
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: HomeOrderTrackingCard(
              key: ValueKey(order.id),
              initialPedido: order,
              isActive: _active,
              pedidoRepository: _repository,
              socketService: widget.socketFactory?.call(order.id),
              onPedidoChanged: _orderChanged),
        ),
    ]);
  }
}
