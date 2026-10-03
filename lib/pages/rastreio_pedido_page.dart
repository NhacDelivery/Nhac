import 'dart:async';
import 'package:nhac/models/chat/pedido_chat_referencia.dart';
import 'package:nhac/services/shared_get.dart';
import 'package:nhac/services/home_order_route_observer.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nhac/models/entrega/rota_entrega_model.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/repositories/entrega_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/live_notification_service.dart';
import 'package:nhac/services/notificacao_historico_service.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';
import 'package:nhac/e2e/e2e_keys.dart';
import 'package:nhac/globals/app_constants.dart';

class _RastreioCacheEntry {
  final PedidoModel pedido;
  final LojasModel? loja;
  final RotaEntregaModel? rota;

  final DateTime saved = DateTime.now();
  _RastreioCacheEntry({
    required this.pedido,
    required this.loja,
    required this.rota,
  });
}

class RastreioPedidoPage extends StatefulWidget {
  final String pedidoId;
  final PedidoRepository? pedidoRepository;
  final LojaRepository? lojaRepository;
  final EntregaRepository? entregaRepository;
  final PedidoStatusSocketService? statusSocket;

  const RastreioPedidoPage({
    super.key,
    required this.pedidoId,
    this.pedidoRepository,
    this.lojaRepository,
    this.entregaRepository,
    this.statusSocket,
  });

  @override
  State<RastreioPedidoPage> createState() => _RastreioPedidoPageState();
}

class _RastreioPedidoPageState extends State<RastreioPedidoPage>
    with RouteAware, WidgetsBindingObserver {
  String get _cacheKey => '${SharedGet.sessionGeneration}|${widget.pedidoId}';
  bool _visible = true;
  bool _foreground = true;
  bool _connected = false;
  bool get _active => _visible && _foreground;
  StreamSubscription<bool>? _connectionSubscription;
  DateTime? _nextRouteAttempt;
  DateTime? _nextLocationAttempt;
  int _requestVersion = 0;
  bool _statusRefreshPending = false;
  Timer? _statusRefreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) homeOrderRouteObserver.subscribe(this, route);
  }

  @override
  void didUpdateWidget(RastreioPedidoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pedidoId == widget.pedidoId) return;
    _requestVersion++;
    _pedido = null;
    _loja = null;
    _rota = null;
    _rotaErro = null;
    _rotaSemCoordenadas = false;
    _motoboyLocation = null;
    _motoboyAtualizadoEm = null;
    _nextRouteAttempt = null;
    _nextLocationAttempt = null;
    _isLoading = true;
    final pedidoId = widget.pedidoId;
    _statusSocket.desconectar().then((_) {
      if (mounted && _active && widget.pedidoId == pedidoId) {
        _statusSocket.conectar(pedidoId);
      }
    });
    _statusRefreshPending = _refreshing;
    _carregarDados();
  }

  @override
  void didPushNext() {
    _visible = false;
    _statusSocket.desconectar();
  }

  @override
  void didPopNext() {
    _visible = true;
    _statusSocket.conectar(widget.pedidoId);
    _carregarDados(silencioso: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_active) {
      _statusSocket.conectar(widget.pedidoId);
      _carregarDados(silencioso: true);
    } else {
      _statusSocket.desconectar();
    }
  }

  static final Map<String, _RastreioCacheEntry> _cache = {};

  late final PedidoRepository _pedidoRepository;
  late final LojaRepository _lojaRepository;
  late final EntregaRepository _entregaRepository;
  late final PedidoStatusSocketService _statusSocket;

  PedidoModel? _pedido;
  LojasModel? _loja;
  bool _carregandoLoja = false;
  bool _erroLoja = false;
  RotaEntregaModel? _rota;
  LatLng? _motoboyLocation;
  DateTime? _motoboyAtualizadoEm;
  bool _motoboyDesatualizado = false;
  bool _rotaSemCoordenadas = false;
  StreamSubscription<StatusPedido>? _statusSubscription;
  Timer? _refreshTimer;
  bool _refreshing = false;
  String? _rotaErro;
  bool _isLoading = true;
  bool _cancelando = false;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String _erro = '';

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  GoogleMapController? _mapController;

  LatLng? get _lojaLocation => _rota == null
      ? null
      : LatLng(_rota!.origem.latitude, _rota!.origem.longitude);

  LatLng? get _clienteLocation => _rota == null
      ? null
      : LatLng(_rota!.destino.latitude, _rota!.destino.longitude);

  @override
  void initState() {
    super.initState();
    _pedidoRepository = widget.pedidoRepository ?? PedidoRepository();
    _lojaRepository = widget.lojaRepository ?? LojaRepository();
    _entregaRepository = widget.entregaRepository ?? EntregaRepository();
    _statusSocket = widget.statusSocket ?? PedidoStatusSocketService();
    WidgetsBinding.instance.addObserver(this);
    _cache.removeWhere((_, entry) =>
        DateTime.now().difference(entry.saved) > const Duration(minutes: 15));
    final cached = _cache.remove(_cacheKey);
    if (cached != null) {
      _pedido = cached.pedido;
      _loja = cached.loja;
      _rota = cached.rota;
      _isLoading = false;
      _cache[_cacheKey] = cached;
    }
    _carregarDados(silencioso: cached != null);
    _conectarStatus();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (ModalRoute.of(context)?.isCurrent == true &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _carregarDados(silencioso: true, recuperarStatus: !_connected);
        }
      },
    );
  }

  @override
  void dispose() {
    _requestVersion++;
    _statusRefreshTimer?.cancel();
    homeOrderRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _statusSubscription?.cancel();
    _refreshTimer?.cancel();
    _statusSocket.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _conectarStatus() async {
    _statusSubscription = _statusSocket.status.listen((novoStatus) async {
      _pedidoRepository.invalidarPedido(widget.pedidoId);
      if (!mounted || !_active) return;
      final anterior = _pedido;
      if (anterior?.status != novoStatus) {
        _requestVersion++;
        _statusRefreshPending = _refreshing;
      }
      if (anterior != null &&
          novoStatus != anterior.status &&
          !anterior.status.terminal) {
        NotificacaoHistoricoService.registrarStatus(
          anterior.usuarioId,
          anterior.id,
          novoStatus,
        );
      }
      if (mounted) {
        _carregarDados(silencioso: true);
      }
    });
    _connectionSubscription = _statusSocket.conectado.listen((connected) {
      _connected = connected;
      if (connected && _active) _carregarDados(silencioso: true);
    });
    await _statusSocket.conectar(widget.pedidoId);
  }

  Future<void> _carregarDados({
    bool silencioso = false,
    bool tentarRota = false,
    bool recuperarStatus = true,
  }) async {
    if (_refreshing || !mounted || !_active) return;
    final session = SharedGet.sessionGeneration;
    final version = _requestVersion;
    _refreshing = true;
    if (!silencioso && mounted) {
      setState(() {
        _isLoading = true;
        _erro = '';
      });
    }

    try {
      final pedido = !recuperarStatus && _pedido != null
          ? _pedido!
          : await _pedidoRepository.buscarPedidoPorId(widget.pedidoId);
      if (!mounted ||
          !_active ||
          session != SharedGet.sessionGeneration ||
          version != _requestVersion) {
        return;
      }
      final anterior = _pedido;
      if (anterior != null &&
          anterior.status != pedido.status &&
          !anterior.status.terminal) {
        NotificacaoHistoricoService.registrarStatus(
          pedido.usuarioId,
          pedido.id,
          pedido.status,
        );
      }
      if (pedido.status.terminal) {
        _refreshTimer?.cancel();
        await _statusSocket.desconectar();
        if (!AppConstants.e2eMode) {
          LiveNotificationService.cancelLiveNotification(pedidoId: pedido.id);
        }
        if (mounted) {
          context.pushReplacement(
            '/pedido-detalhes?pedidoId=${Uri.encodeQueryComponent(pedido.id)}',
          );
        }
        return;
      }
      // Status e ações não dependem de loja, GPS ou serviço externo de rotas.
      setState(() {
        _pedido = pedido;
        _isLoading = false;
        _erro = '';
      });
      LojasModel? loja = _loja;
      RotaEntregaModel? rota = _rota;
      String? rotaErro;

      if (loja == null) {
        setState(() {
          _carregandoLoja = true;
          _erroLoja = false;
        });
        try {
          loja = await _lojaRepository.buscarLoja(pedido.lojaId);
          if (mounted &&
              version == _requestVersion &&
              session == SharedGet.sessionGeneration) {
            setState(() {
              _loja = loja;
              _erroLoja = loja == null;
            });
          }
        } catch (_) {
          if (mounted) setState(() => _erroLoja = true);
        } finally {
          if (mounted) setState(() => _carregandoLoja = false);
        }
      }

      if (!mounted ||
          !_active ||
          session != SharedGet.sessionGeneration ||
          version != _requestVersion) {
        return;
      }
      if (tentarRota) _entregaRepository.invalidarRota(widget.pedidoId);

      if (tentarRota ||
          (rota == null &&
              !_rotaSemCoordenadas &&
              (_nextRouteAttempt == null ||
                  DateTime.now().isAfter(_nextRouteAttempt!)))) {
        try {
          _nextRouteAttempt = DateTime.now().add(const Duration(minutes: 2));
          rota = await _entregaRepository.buscarRota(widget.pedidoId);
          if (!rota.origem.isValido || !rota.destino.isValido) {
            rota = null;
            _rotaSemCoordenadas = true;
            rotaErro =
                'Endereço sem coordenadas. O mapa e a distância estão indisponíveis para este pedido.';
          } else {
            _rotaSemCoordenadas = false;
          }
        } catch (e) {
          _rotaSemCoordenadas = e.toString().toLowerCase().contains(
                'coordenad',
              );
          if (_rotaSemCoordenadas) rota = null;
          rotaErro = e.toString();
        }
      } else {
        rotaErro = _rotaErro;
      }
      LatLng? motoboyLocation = _motoboyLocation;
      if (!mounted ||
          !_active ||
          session != SharedGet.sessionGeneration ||
          version != _requestVersion) {
        return;
      }
      DateTime? motoboyAtualizadoEm = _motoboyAtualizadoEm;
      bool motoboyDesatualizado = _motoboyDesatualizado;
      if (pedido.entregador != null &&
          (_nextLocationAttempt == null ||
              DateTime.now().isAfter(_nextLocationAttempt!))) {
        try {
          _nextLocationAttempt =
              DateTime.now().add(const Duration(seconds: 30));
          final ponto = await _entregaRepository.buscarLocalizacaoEntregador(
            widget.pedidoId,
          );
          if (ponto != null && ponto.isValido) {
            motoboyLocation = LatLng(ponto.latitude, ponto.longitude);
            motoboyAtualizadoEm = ponto.atualizadaEm;
            motoboyDesatualizado = ponto.atualizadaEm == null ||
                DateTime.now().difference(ponto.atualizadaEm!) >
                    const Duration(minutes: 2);
          } else if (motoboyLocation != null) {
            motoboyDesatualizado = true;
          }
        } catch (_) {
          if (motoboyLocation != null) motoboyDesatualizado = true;
        }
      }

      if (!mounted ||
          !_active ||
          session != SharedGet.sessionGeneration ||
          version != _requestVersion) {
        return;
      }
      setState(() {
        _pedido = pedido;
        _loja = loja;
        _rota = rota;
        _rotaErro = rotaErro;
        _motoboyLocation = motoboyLocation;
        _motoboyAtualizadoEm = motoboyAtualizadoEm;
        _motoboyDesatualizado = motoboyDesatualizado;
        _isLoading = false;
        _erro = '';
      });

      _cache.remove(_cacheKey);
      _cache[_cacheKey] = _RastreioCacheEntry(
        pedido: pedido,
        loja: loja,
        rota: rota,
      );
      if (_cache.length > 5) {
        _cache.remove(_cache.keys.first);
      }

      _publicarNotificacaoAoVivo();
    } catch (e) {
      if (!mounted ||
          !_active ||
          session != SharedGet.sessionGeneration ||
          version != _requestVersion) {
        return;
      }
      if (_pedido != null && _loja != null) {
        if (_motoboyLocation != null) {
          setState(() => _motoboyDesatualizado = true);
        }
        return;
      }
      setState(() {
        _erro = 'Erro ao carregar dados do pedido: $e';
        _isLoading = false;
      });
    } finally {
      _refreshing = false;
      if (_statusRefreshPending && mounted && _active) {
        _statusRefreshPending = false;
        _statusRefreshTimer?.cancel();
        _statusRefreshTimer = Timer(const Duration(milliseconds: 300),
            () => _carregarDados(silencioso: true));
      }
    }
  }

  void _publicarNotificacaoAoVivo() {
    if (AppConstants.e2eMode) return;
    final pedido = _pedido;
    if (pedido == null || pedido.status.terminal) return;

    var nomeProduto = 'Seu pedido';
    if (pedido.itens.isNotEmpty) {
      nomeProduto = pedido.itens.first.nome;
      if (pedido.itens.length > 1) {
        nomeProduto += ' e mais';
      }
    }

    final tempo = _tempoEstimadoMinutos();
    LiveNotificationService.showLiveNotification(
      pedidoId: widget.pedidoId,
      nomeProduto: nomeProduto,
      status: pedido.status.label,
      tempoEstimado: tempo > 0 ? '$tempo min' : pedido.status.label,
      progresso: pedido.status.stage,
    );
  }

  void _mostrarResultadoCancelamento(String mensagem) {
    // Aguarda a troca dos Scaffolds de carregamento/erro terminar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    });
  }

  Future<void> _cancelarPedido() async {
    if (_pedido?.status != StatusPedido.pendente || _cancelando) return;

    setState(() => _cancelando = true);
    try {
      await _pedidoRepository.cancelarPedido(widget.pedidoId);
    } catch (e) {
      if (!mounted || !_active) return;
      setState(() => _cancelando = false);
      _mostrarResultadoCancelamento(e.toString());
      return;
    }

    if (!mounted) return;
    await _carregarDados(silencioso: true);
    if (!mounted) return;
    setState(() => _cancelando = false);
    _mostrarResultadoCancelamento('Pedido cancelado.');
  }

  Future<void> _abrirMensagemRestaurante() async {
    final loja = _loja;
    if (loja == null) return;
    final pedido = _pedido;
    context.push(
      '/chat-loja',
      extra: {
        'lojaId': loja.id,
        'lojaNome': loja.nome,
        // Identifica o pedido: a mesma conversa reúne compras diferentes.
        if (pedido != null) 'pedido': PedidoChatReferencia.fromPedido(pedido),
      },
    );
  }

  int _tempoEstimadoMinutos() {
    final pedido = _pedido;
    if (pedido == null || pedido.status.terminal) return 0;

    if (pedido.status == StatusPedido.saiuEntrega) {
      return _rota?.duracaoEstimadaMinutos ?? 0;
    }

    return _loja?.dadosOperacionais?.tempoEntregaMax ??
        _rota?.duracaoEstimadaMinutos ??
        45;
  }

  String _statusPedidoTexto() {
    final status = _pedido?.status;
    final entregador = _pedido?.entregador;
    if (entregador != null) {
      if (status == StatusPedido.preparando) {
        return '${entregador.nome} aceitou sua entrega';
      }
      if (status == StatusPedido.saiuEntrega) {
        return '${entregador.nome} está a caminho';
      }
    }
    return status?.label ?? 'Pedido em andamento';
  }

  Widget _buildMapa() {
    if (AppConstants.e2eMode) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('Mapa indisponível no modo E2E'),
      );
    }
    final origem = _lojaLocation;
    final destino = _clienteLocation;

    if (origem == null || destino == null) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _rotaErro ??
                  'Rota ainda indisponível. Confira as coordenadas da loja e do endereço de entrega.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => _carregarDados(tentarRota: true),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final pontos = _rota!.waypoints.isNotEmpty
        ? _rota!.waypoints.map((p) => LatLng(p.latitude, p.longitude)).toList()
        : <LatLng>[origem, destino];

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: origem, zoom: 14.5),
      onMapCreated: (controller) {
        _mapController = controller;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted || !_active) return;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  origem.latitude < destino.latitude
                      ? origem.latitude
                      : destino.latitude,
                  origem.longitude < destino.longitude
                      ? origem.longitude
                      : destino.longitude,
                ),
                northeast: LatLng(
                  origem.latitude > destino.latitude
                      ? origem.latitude
                      : destino.latitude,
                  origem.longitude > destino.longitude
                      ? origem.longitude
                      : destino.longitude,
                ),
              ),
              50,
            ),
          );
        });
      },
      markers: {
        Marker(
          markerId: const MarkerId('loja'),
          position: origem,
          infoWindow: InfoWindow(title: _loja?.nome ?? 'Loja'),
        ),
        Marker(
          markerId: const MarkerId('cliente'),
          position: destino,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Endereço de entrega'),
        ),
        if (_motoboyLocation != null)
          Marker(
            markerId: const MarkerId('motoboy'),
            position: _motoboyLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: _motoboyDesatualizado
                  ? 'Última posição conhecida (desatualizada)'
                  : 'Entregador',
            ),
          ),
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('rota'),
          points: pontos,
          color: Colors.red,
          width: 4,
        ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: _buildConteudo(context),
    );
  }

  Widget _buildConteudo(BuildContext context) {
    if (_isLoading) {
      return const LoadingNhac(telaCheia: true);
    }

    if (_erro.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_erro, textAlign: TextAlign.center),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _carregarDados,
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pedido == null) {
      return const Scaffold(
        body: Center(child: Text('Pedido não encontrado.')),
      );
    }

    final status = _pedido!.status;
    final distanciaKm = _rota?.distanciaKm ?? 0;
    final tempoEstimadoMin = _tempoEstimadoMinutos();
    final previsao = DateTime.now().add(Duration(minutes: tempoEstimadoMin));
    final horaPrevisao =
        status.terminal ? '--:--' : DateFormat('HH:mm').format(previsao);
    final tempoExibicao = status == StatusPedido.entregue
        ? 'Entregue'
        : status == StatusPedido.cancelado
            ? 'Cancelado'
            : '$tempoEstimadoMin min total';
    final distanciaTexto =
        _rota == null ? 'Indisponível' : '${distanciaKm.toStringAsFixed(1)} km';
    final tempoEstimadoTexto =
        tempoEstimadoMin > 0 ? '$tempoEstimadoMin min' : '--';

    int quantidadeItens = _pedido!.itens.fold(
      0,
      (sum, item) => sum + item.quantidade,
    );

    return Scaffold(
      key: E2EKeys.trackingRoot,
      body: Stack(
        children: [
          Semantics(
            key: E2EKeys.trackingOrderId,
            value: widget.pedidoId,
            child: const SizedBox.shrink(),
          ),
          _buildMapa(),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16.h,
            left: 16.w,
            child: InkWell(
              onTap: () {
                if (GoRouter.of(context).canPop()) {
                  GoRouter.of(context).pop();
                } else {
                  GoRouter.of(context).go('/home-page');
                }
              },
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20.sp,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16.h,
            left: 70.w,
            right: 16.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Semantics(
                          key: E2EKeys.trackingStatus,
                          value: _pedido!.status.apiValue,
                          child: Text(
                            _statusPedidoTexto(),
                            key: const Key('pedido-status-text'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${_pedido!.enderecoEntrega.rua}, ${_pedido!.enderecoEntrega.numero}',
                    style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Painel Inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Previsão até $horaPrevisao',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '$quantidadeItens Itens • $tempoExibicao',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(_pedido!.valorTotal),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Divider(color: Colors.grey.shade300, height: 1),
                  SizedBox(height: 16.h),
                  _buildCodigoEntregaCard(),
                  _buildEntregadorCard(),
                  if (_erroLoja)
                    TextButton(
                        onPressed: _carregarDados,
                        child: const Text(
                            'Não foi possível consultar a loja. Tentar novamente')),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25.r),
                        child: (_loja?.imagemUrl.isNotEmpty ?? false)
                            ? CachedNetworkImage(
                                imageUrl: _loja!.imagemUrl,
                                width: 50.r,
                                height: 50.r,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 50.r,
                                height: 50.r,
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.store,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restaurante',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12.sp,
                              ),
                            ),
                            Text(
                              _loja?.nome ??
                                  (_carregandoLoja
                                      ? 'Carregando restaurante...'
                                      : 'Restaurante indisponível'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _abrirMensagemRestaurante(),
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.message,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  if (_motoboyLocation != null &&
                      _motoboyAtualizadoEm != null) ...[
                    Text(
                      '${_motoboyDesatualizado ? 'Última posição conhecida · desatualizada' : 'Posição do entregador'}: ${DateFormat('dd/MM HH:mm').format(_motoboyAtualizadoEm!.toLocal())}',
                      style: TextStyle(
                        color: _motoboyDesatualizado
                            ? Colors.deepOrange
                            : Colors.grey.shade600,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distância',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14.sp,
                        ),
                      ),
                      Text(
                        distanciaTexto,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tempo estimado',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14.sp,
                        ),
                      ),
                      Text(
                        tempoEstimadoTexto,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                  if (status == StatusPedido.pendente) ...[
                    SizedBox(height: 20.h),
                    if (_pedido!.formaPagamento.toUpperCase() == 'PIX' ||
                        _pedido!.formaPagamento.toUpperCase() == 'CARTAO') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context.push(
                            '/pagamento?pedidoId=${widget.pedidoId}',
                          ),
                          icon: const Icon(Icons.payment),
                          label: const Text('Continuar pagamento'),
                        ),
                      ),
                      SizedBox(height: 8.h),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const Key('pedido-cancelar-button'),
                        onPressed: _cancelando ? null : _cancelarPedido,
                        child: Text(
                          _cancelando ? 'Cancelando...' : 'Cancelar pedido',
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodigoEntregaCard() {
    if (_pedido?.status != StatusPedido.saiuEntrega) {
      return const SizedBox.shrink();
    }

    final codigo = _pedido?.codigoEntrega;
    final temCodigo = codigo != null && codigo.trim().isNotEmpty;

    return Container(
      key: const Key('cartao-codigo-entrega'),
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBD9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFFF6961).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pin_outlined,
                color: const Color(0xFF5D201C),
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Código de entrega',
                style: TextStyle(
                  color: const Color(0xFF5D201C),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (temCodigo)
            Semantics(
              label: 'Código de entrega: ${codigo.split('').join(' ')}',
              excludeSemantics: true,
              child: Text(
                codigo,
                style: TextStyle(
                  color: const Color(0xFF5D201C),
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8.w,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoadingNhac(telaCheia: false, tamanho: 20.0),
                  SizedBox(width: 8.w),
                  Text(
                    'Carregando código…',
                    style: TextStyle(
                      color: const Color(0xFF5D201C),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 6.h),
          Text(
            'Informe este código ao entregador só quando receber o pedido.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildEntregadorCard() {
    final entregador = _pedido?.entregador;
    if (entregador == null) return const SizedBox.shrink();

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
      key: const Key('cartao-entregador-rastreio'),
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22.r),
            child: entregador.fotoUrl != null && entregador.fotoUrl!.isNotEmpty
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entregador.nome,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                          color: const Color(0xFF5D201C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (temAvaliacao) ...[
                      SizedBox(width: 6.w),
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
                  ],
                ),
                if (infoVeiculo.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    infoVeiculo,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
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
