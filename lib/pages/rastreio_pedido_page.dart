import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import 'package:nhac/services/pedido_status_socket_service.dart';

class RastreioPedidoPage extends StatefulWidget {
  final String pedidoId;

  const RastreioPedidoPage({
    super.key,
    required this.pedidoId,
  });

  @override
  State<RastreioPedidoPage> createState() => _RastreioPedidoPageState();
}

class _RastreioPedidoPageState extends State<RastreioPedidoPage> {
  final PedidoRepository _pedidoRepository = PedidoRepository();
  final LojaRepository _lojaRepository = LojaRepository();
  final EntregaRepository _entregaRepository = EntregaRepository();
  final PedidoStatusSocketService _statusSocket = PedidoStatusSocketService();

  PedidoModel? _pedido;
  LojasModel? _loja;
  RotaEntregaModel? _rota;
  StreamSubscription<StatusPedido>? _statusSubscription;
  bool _isLoading = true;
  bool _cancelando = false;
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
    _carregarDados();
    _conectarStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _statusSocket.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _conectarStatus() async {
    _statusSubscription = _statusSocket.status.listen((_) {
      if (mounted) {
        _carregarDados(silencioso: true);
      }
    });
    await _statusSocket.conectar(widget.pedidoId);
  }

  Future<void> _carregarDados({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        _isLoading = true;
        _erro = '';
      });
    }

    try {
      final pedido = await _pedidoRepository.buscarPedidoPorId(widget.pedidoId);
      LojasModel? loja;
      RotaEntregaModel? rota;

      try {
        loja = await _lojaRepository.buscarLoja(pedido.lojaId);
      } catch (_) {}

      try {
        rota = await _entregaRepository.buscarRota(widget.pedidoId);
      } catch (_) {
        // O pedido continua acessível mesmo se a rota ainda não estiver disponível.
      }

      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _loja = loja;
        _rota = rota;
        _isLoading = false;
        _erro = '';
      });

      _publicarNotificacaoAoVivo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao carregar dados do pedido: $e';
        _isLoading = false;
      });
    }
  }

  void _publicarNotificacaoAoVivo() {
    final pedido = _pedido;
    if (pedido == null) return;

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

  Future<void> _cancelarPedido() async {
    if (_pedido?.status != StatusPedido.pendente || _cancelando) return;

    setState(() => _cancelando = true);
    try {
      await _pedidoRepository.cancelarPedido(widget.pedidoId);
      await _carregarDados(silencioso: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido cancelado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
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

  String _statusPedidoTexto() => _pedido?.status.label ?? 'Pedido em andamento';

  Widget _buildMapa() {
    final origem = _lojaLocation;
    final destino = _clienteLocation;

    if (origem == null || destino == null) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('Rota ainda indisponível'),
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
      body: Stack(
        children: [
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
                      Text(
                        _statusPedidoTexto(),
                        key: const Key('pedido-status-text'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16.sp),
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
                      Column(
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
                  SizedBox(height: 24.h),
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
}
