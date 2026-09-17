// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/services/live_notification_service.dart';
import 'package:nhac/globals/ui_utils.dart';

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
  PedidoModel? _pedido;
  LojasModel? _loja;
  bool _isLoading = true;
  String _erro = '';

  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  GoogleMapController? _mapController;

  final LatLng _lojaLocation = const LatLng(-23.550520, -46.633308);
  LatLng _clienteLocation = const LatLng(-23.558520, -46.640308);

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final pedidoRepo = PedidoRepository();
      final lojaRepo = LojaRepository();

      final pedido = await pedidoRepo.buscarPedidoPorId(widget.pedidoId);

      LojasModel? loja;
      try {
        loja = await lojaRepo.buscarLoja(pedido.lojaId);
      } catch (e) {
        debugPrint("Erro ao buscar loja do pedido: $e");
       
      }

      if (mounted) {
        setState(() {
          _pedido = pedido;
          _loja = loja;
        });
      }

      await _atualizarCoordenadasCliente();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        final tempoEstimadoMin = _calcularTempoEstimadoMinutos();
        final statusTexto = _statusPedidoTexto();
        
        int stageIndex = 0;
        final status = (_pedido?.status ?? '').toUpperCase();
        if (status == 'AGUARDANDO_PAGAMENTO' || status == 'PENDENTE') stageIndex = 0;
        else if (status == 'PAGO' || status == 'CONFIRMADO' || status == 'APROVADO') stageIndex = 1;
        else if (status == 'EM_PREPARO' || status == 'PREPARANDO') stageIndex = 2;
        else if (status == 'SAIU_PARA_ENTREGA') stageIndex = 3;
        else if (status == 'ENTREGUE') stageIndex = 4;
        
        String nomeProduto = 'Seu pedido';
        if (_pedido?.itens != null && _pedido!.itens.isNotEmpty) {
           nomeProduto = _pedido!.itens.first.nome;
           if (_pedido!.itens.length > 1) {
              nomeProduto += ' e mais';
           }
        }
        
        LiveNotificationService.showLiveNotification(
          pedidoId: widget.pedidoId,
          nomeProduto: nomeProduto,
          status: statusTexto,
          tempoEstimado: tempoEstimadoMin > 0 ? '$tempoEstimadoMin min' : 'Entregue',
          progresso: stageIndex,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar dados do pedido: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _atualizarCoordenadasCliente() async {
    final endereco = _pedido?.enderecoEntrega;
    if (endereco == null) return;

    final enderecoCompleto = [
      endereco.rua,
      endereco.numero,
      endereco.bairro,
      endereco.cidade,
      endereco.estado,
      endereco.cep,
    ].where((valor) => valor.trim().isNotEmpty).join(', ');

    if (enderecoCompleto.trim().isEmpty) return;

    try {
      final locations = await locationFromAddress(enderecoCompleto);
      if (locations.isNotEmpty && mounted) {
        final localizacao = locations.first;
        setState(() {
          _clienteLocation =
              LatLng(localizacao.latitude, localizacao.longitude);
        });
      }
    } catch (_) {
      
    }
  }

  Future<void> _abrirMensagemRestaurante() async {
    context.push('/chat-loja', extra: {
      'lojaId': _loja!.id,
      'lojaNome': _loja!.nome,
    });
  }

  double _calcularDistanciaKm() {
    const raioTerra = 6371.0;
    final lat1 = _lojaLocation.latitude * (math.pi / 180);
    final lat2 = _clienteLocation.latitude * (math.pi / 180);
    final dLat =
        (_clienteLocation.latitude - _lojaLocation.latitude) * (math.pi / 180);
    final dLng = (_clienteLocation.longitude - _lojaLocation.longitude) *
        (math.pi / 180);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return raioTerra * c;
  }

  int _calcularTempoEstimadoMinutos() {
    final distanciaKm = _calcularDistanciaKm();
    final tempoBaseLoja = _loja?.dadosOperacionais?.tempoEntregaMax ?? 45;
    final minutosPorKm = (distanciaKm * 6).round();
    final status = (_pedido?.status ?? '').toUpperCase();

    switch (status) {
      case 'AGUARDANDO_PAGAMENTO':
      case 'PENDENTE':
        return math.max(25, tempoBaseLoja + 10);
      case 'PAGO':
      case 'CONFIRMADO':
      case 'APROVADO':
        return math.max(20, (tempoBaseLoja * 0.7 + minutosPorKm).round());
      case 'EM_PREPARO':
      case 'PREPARANDO':
        return math.max(15, (tempoBaseLoja * 0.5 + minutosPorKm).round());
      case 'SAIU_PARA_ENTREGA':
        return math.max(10, minutosPorKm + 5);
      case 'ENTREGUE':
        return 0;
      default:
        return math.max(20, tempoBaseLoja + minutosPorKm);
    }
  }

  String _statusPedidoTexto() {
    final status = (_pedido?.status ?? '').toUpperCase();

    switch (status) {
      case 'AGUARDANDO_PAGAMENTO':
        return 'Aguardando pagamento';
      case 'PENDENTE':
        return 'Pedido pendente';
      case 'PAGO':
      case 'CONFIRMADO':
      case 'APROVADO':
        return 'Pagamento confirmado';
      case 'EM_PREPARO':
      case 'PREPARANDO':
        return 'Em preparo';
      case 'SAIU_PARA_ENTREGA':
        return 'Saiu para entrega';
      case 'ENTREGUE':
        return 'Entregue';
      case 'CANCELADO':
        return 'Pedido cancelado';
      case 'RECUSADO':
      case 'EXPIRADO':
        return 'Pagamento falhou';
      default:
        if (status.isEmpty) return 'Pedido em andamento';
        return status.replaceAll('_', ' ').replaceAllMapped(
              RegExp(r'\b\w'),
              (match) => match.group(0)!.toUpperCase(),
            );
    }
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

    final distanciaKm = _calcularDistanciaKm();
    final tempoEstimadoMin = _calcularTempoEstimadoMinutos();
    final previsao = DateTime.now().add(Duration(minutes: tempoEstimadoMin));
    final horaPrevisao = DateFormat('HH:mm').format(previsao);
    final tempoExibicao = tempoEstimadoMin > 0 ? '$tempoEstimadoMin min total' : 'Entregue';
    final distanciaTexto = '${distanciaKm.toStringAsFixed(1)} km';
    final tempoEstimadoTexto = '$tempoEstimadoMin min';
    
    int quantidadeItens =
        _pedido!.itens.fold(0, (sum, item) => sum + item.quantidade);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _lojaLocation,
              zoom: 14.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(
                        _lojaLocation.latitude < _clienteLocation.latitude
                            ? _lojaLocation.latitude
                            : _clienteLocation.latitude,
                        _lojaLocation.longitude < _clienteLocation.longitude
                            ? _lojaLocation.longitude
                            : _clienteLocation.longitude,
                      ),
                      northeast: LatLng(
                        _lojaLocation.latitude > _clienteLocation.latitude
                            ? _lojaLocation.latitude
                            : _clienteLocation.latitude,
                        _lojaLocation.longitude > _clienteLocation.longitude
                            ? _lojaLocation.longitude
                            : _clienteLocation.longitude,
                      ),
                    ),
                    50.0, // padding
                  ),
                );
              });
            },
            markers: {
              Marker(
                markerId: const MarkerId('loja'),
                position: _lojaLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: _loja!.nome),
              ),
              Marker(
                markerId: const MarkerId('cliente'),
                position: _clienteLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow: InfoWindow(
                  title: 'Endereço do cliente',
                  snippet:
                      '${_pedido!.enderecoEntrega.rua}, ${_pedido!.enderecoEntrega.numero}',
                ),
              ),
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('rota'),
                points: [_lojaLocation, _clienteLocation],
                color: Colors.red.withValues(alpha: 0.5),
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                    ],
                  ),
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
