import 'dart:async';

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

  const _RastreioCacheEntry({
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

class _RastreioPedidoPageState extends State<RastreioPedidoPage> {
  static final Map<String, _RastreioCacheEntry> _cache = {};

  late final PedidoRepository _pedidoRepository;
  late final LojaRepository _lojaRepository;
  late final EntregaRepository _entregaRepository;
  late final PedidoStatusSocketService _statusSocket;

  PedidoModel? _pedido;
  LojasModel? _loja;
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

  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
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
    final cached = _cache.remove(widget.pedidoId);
    if (cached != null) {
      _pedido = cached.pedido;
      _loja = cached.loja;
      _rota = cached.rota;
      _isLoading = false;
      _cache[widget.pedidoId] = cached;
    }
    _carregarDados(silencioso: cached != null);
    _conectarStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _carregarDados(silencioso: true));
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _refreshTimer?.cancel();
    _statusSocket.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _conectarStatus() async {
    _statusSubscription = _statusSocket.status.listen((novoStatus) async {
      final anterior = _pedido;
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
    await _statusSocket.conectar(widget.pedidoId);
  }

  Future<void> _carregarDados({bool silencioso = false, bool tentarRota = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silencioso && mounted) {
      setState(() {
        _isLoading = true;
        _erro = '';
      });
    }

    try {
      final pedido = await _pedidoRepository.buscarPedidoPorId(widget.pedidoId);
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
          LiveNotificationService.cancelLiveNotification(
              pedidoId: pedido.id);
        }
        if (mounted) {
          context.pushReplacement(
            '/pedido-detalhes?pedidoId=${Uri.encodeQueryComponent(pedido.id)}',
          );
        }
        return;
      }
      LojasModel? loja = _loja;
      RotaEntregaModel? rota = _rota;
      String? rotaErro;

      try {
        loja = await _lojaRepository.buscarLoja(pedido.lojaId);
      } catch (_) {}

      if (!_rotaSemCoordenadas || tentarRota) {
        try {
          rota = await _entregaRepository.buscarRota(widget.pedidoId);
          if (rota.origem.latitude == 0 && rota.origem.longitude == 0 ||
              rota.destino.latitude == 0 && rota.destino.longitude == 0) {
            rota = null;
            _rotaSemCoordenadas = true;
            rotaErro = 'Endereço sem coordenadas. O mapa e a distância estão indisponíveis para este pedido.';
          } else {
            _rotaSemCoordenadas = false;
          }
        } catch (e) {
          _rotaSemCoordenadas = e.toString().toLowerCase().contains('coordenad');
          if (_rotaSemCoordenadas) rota = null;
          rotaErro = _rotaSemCoordenadas
              ? 'Endereço sem coordenadas. O mapa e a distância estão indisponíveis para este pedido.'
              : 'Não foi possível carregar a rota. Tente novamente.';
        }
      } else {
        rotaErro = _rotaErro;
      }
      LatLng? motoboyLocation = _motoboyLocation;
      DateTime? motoboyAtualizadoEm = _motoboyAtualizadoEm;
      bool motoboyDesatualizado = _motoboyDesatualizado;
      try {
        final ponto = await _entregaRepository.buscarLocalizacaoEntregador(widget.pedidoId);
        if (ponto != null && !(ponto.latitude == 0 && ponto.longitude == 0)) {
          motoboyLocation = LatLng(ponto.latitude, ponto.longitude);
          motoboyAtualizadoEm = ponto.atualizadaEm ?? DateTime.now();
          motoboyDesatualizado = false;
        } else if (motoboyLocation != null) {
          motoboyDesatualizado = true;
        }
      } catch (_) {
        if (motoboyLocation != null) motoboyDesatualizado = true;
      }

      if (!mounted) return;
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

      _cache.remove(widget.pedidoId);
      _cache[widget.pedidoId] = _RastreioCacheEntry(
        pedido: pedido,
        loja: loja,
        rota: rota,
      );
      if (_cache.length > 5) {
        _cache.remove(_cache.keys.first);
      }

      _publicarNotificacaoAoVivo();
    } catch (e) {
      if (!mounted) return;
      if (_pedido != null && _loja != null) {
        if (_motoboyLocation != null) setState(() => _motoboyDesatualizado = true);
        return;
      }
      setState(() {
        _erro = 'Erro ao carregar dados do pedido: $e';
        _isLoading = false;
      });
    } finally {
      _refreshing = false;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
    context.push('/chat-loja', extra: {
      'lojaId': loja.id,
      'lojaNome': loja.nome,
    });
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_rotaErro ?? 'Rota ainda indisponível. Confira as coordenadas da loja e do endereço de entrega.',
              textAlign: TextAlign.center),
          TextButton(onPressed: () => _carregarDados(tentarRota: true), child: const Text('Tentar novamente')),
        ]),
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
          if (!mounted) return;
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
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(title: _motoboyDesatualizado
                ? 'Última posição conhecida (desatualizada)'
                : 'Entregador'),
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

    if (_pedido == null || _loja == null) {
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

    int quantidadeItens =
        _pedido!.itens.fold(0, (sum, item) => sum + item.quantidade);

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
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 20.sp, color: Colors.black),
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
                                fontWeight: FontWeight.bold, fontSize: 16.sp),
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
                      offset: Offset(0, -2)),
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
                                  fontWeight: FontWeight.bold, fontSize: 20.sp),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '$quantidadeItens Itens • $tempoExibicao',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 14.sp),
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
                                color: Colors.red),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Total',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14.sp),
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
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25.r),
                        child: _loja!.imagemUrl.isNotEmpty
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
                                child: Icon(Icons.store,
                                    color: Colors.grey.shade400),
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
                                  color: Colors.grey.shade500, fontSize: 12.sp),
                            ),
                            Text(
                              _loja!.nome,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16.sp),
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
                          child: Icon(Icons.message,
                              color: Colors.white, size: 24.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  if (_motoboyLocation != null && _motoboyAtualizadoEm != null) ...[
                    Text(
                      '${_motoboyDesatualizado ? 'Última posição conhecida · desatualizada' : 'Posição do entregador'}: ${DateFormat('dd/MM HH:mm').format(_motoboyAtualizadoEm!.toLocal())}',
                      style: TextStyle(color: _motoboyDesatualizado ? Colors.deepOrange : Colors.grey.shade600, fontSize: 12.sp),
                    ),
                    SizedBox(height: 8.h),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distância',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14.sp),
                      ),
                      Text(
                        distanciaTexto,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16.sp),
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
                            color: Colors.grey.shade500, fontSize: 14.sp),
                      ),
                      Text(
                        tempoEstimadoTexto,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16.sp),
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
                          onPressed: () => context.push('/pagamento?pedidoId=${widget.pedidoId}'),
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
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntregadorCard() {
    final entregador = _pedido?.entregador;
    if (entregador == null) return const SizedBox.shrink();

    final infoVeiculo = [
      if (entregador.modeloVeiculo != null && entregador.modeloVeiculo!.isNotEmpty)
        entregador.modeloVeiculo,
      if (entregador.corVeiculo != null && entregador.corVeiculo!.isNotEmpty)
        entregador.corVeiculo,
      if (entregador.placaVeiculo != null && entregador.placaVeiculo!.isNotEmpty)
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
                      child: Icon(Icons.two_wheeler,
                          color: const Color(0xFFFF6961), size: 22.r),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 44.r,
                      height: 44.r,
                      color: const Color(0xFFFFE7E5),
                      child: Icon(Icons.two_wheeler,
                          color: const Color(0xFFFF6961), size: 22.r),
                    ),
                  )
                : Container(
                    width: 44.r,
                    height: 44.r,
                    color: const Color(0xFFFFE7E5),
                    child: Icon(Icons.two_wheeler,
                        color: const Color(0xFFFF6961), size: 22.r),
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
                      Icon(Icons.star_rounded,
                          color: Colors.amber.shade700, size: 16.sp),
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
