import 'package:nhac/models/pedido/entregador_pedido_model.dart';
import 'package:nhac/models/pedido/item_pedido_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/models/usuario/endereco_model.dart';

class PedidoModel {
  final String id;
  final String usuarioId;
  final String lojaId;
  final String lojaNome;
  final double valorTotal;
  final double taxaFrete;
  final String formaPagamento;
  final double? trocoPara;
  final String? observacao;
  final EnderecoModel enderecoEntrega;
  final List<ItemPedidoModel> itens;
  final StatusPedido status;
  final DateTime? criadoEm;
  final String? codigoEntrega;
  final EntregadorPedidoModel? entregador;
  final bool entregadorAvaliado;

  const PedidoModel({
    required this.id,
    required this.usuarioId,
    required this.lojaId,
    required this.lojaNome,
    required this.valorTotal,
    required this.taxaFrete,
    required this.formaPagamento,
    this.trocoPara,
    this.observacao,
    required this.enderecoEntrega,
    required this.itens,
    required this.status,
    this.criadoEm,
    this.codigoEntrega,
    this.entregador,
    this.entregadorAvaliado = false,
  });

  String get statusApi => status.apiValue;

  /// Converte para Map para persistência ou cache.
  /// IMPORTANTE: `codigoEntrega` nunca é incluído aqui para não ser salvo em disco.
  Map<String, dynamic> toMap() => {
    'id': id,
    'usuarioId': usuarioId,
    'lojaId': lojaId,
    'lojaNome': lojaNome,
    'valorTotal': valorTotal,
    'taxaFrete': taxaFrete,
    'formaPagamento': formaPagamento,
    'trocoPara': trocoPara,
    'observacao': observacao,
    'enderecoEntrega': enderecoEntrega.toMap(),
    'itens': itens.map((item) => item.toMap()).toList(),
    'status': status.apiValue,
    'criadoEm': criadoEm?.toIso8601String(),
    'entregador': entregador?.toMap(),
    'entregadorAvaliado': entregadorAvaliado,
  };

  factory PedidoModel.fromMap(Map<String, dynamic> map) {
    return PedidoModel(
      id: map['id']?.toString() ?? '',
      usuarioId: map['usuarioId']?.toString() ?? '',
      lojaId: map['lojaId']?.toString() ?? '',
      lojaNome: map['lojaNome']?.toString() ?? '',
      valorTotal:
          num.tryParse(map['valorTotal']?.toString() ?? '0')?.toDouble() ?? 0,
      taxaFrete:
          num.tryParse(map['taxaFrete']?.toString() ?? '0')?.toDouble() ?? 0,
      formaPagamento: map['formaPagamento']?.toString() ?? '',
      trocoPara: map['trocoPara'] == null
          ? null
          : num.tryParse(map['trocoPara'].toString())?.toDouble(),
      observacao: map['observacao']?.toString(),
      enderecoEntrega: EnderecoModel.fromMap(
        Map<String, dynamic>.from(map['enderecoEntrega'] ?? const {}),
      ),
      itens: (map['itens'] as List? ?? const [])
          .map((item) => ItemPedidoModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      status: StatusPedido.fromApi(map['status']?.toString()),
      criadoEm: DateTime.tryParse(map['criadoEm']?.toString() ?? ''),
      codigoEntrega: map['codigoEntrega']?.toString(),
      entregador: map['entregador'] != null && map['entregador'] is Map
          ? EntregadorPedidoModel.fromMap(
              Map<String, dynamic>.from(map['entregador'] as Map),
            )
          : null,
      entregadorAvaliado: map['entregadorAvaliado'] == true,
    );
  }

  PedidoModel copyWith({
    String? id,
    String? usuarioId,
    String? lojaId,
    String? lojaNome,
    double? valorTotal,
    double? taxaFrete,
    String? formaPagamento,
    double? trocoPara,
    String? observacao,
    EnderecoModel? enderecoEntrega,
    List<ItemPedidoModel>? itens,
    StatusPedido? status,
    DateTime? criadoEm,
    String? codigoEntrega,
    EntregadorPedidoModel? entregador,
    bool? entregadorAvaliado,
  }) {
    return PedidoModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      lojaId: lojaId ?? this.lojaId,
      lojaNome: lojaNome ?? this.lojaNome,
      valorTotal: valorTotal ?? this.valorTotal,
      taxaFrete: taxaFrete ?? this.taxaFrete,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      trocoPara: trocoPara ?? this.trocoPara,
      observacao: observacao ?? this.observacao,
      enderecoEntrega: enderecoEntrega ?? this.enderecoEntrega,
      itens: itens ?? this.itens,
      status: status ?? this.status,
      criadoEm: criadoEm ?? this.criadoEm,
      codigoEntrega: codigoEntrega ?? this.codigoEntrega,
      entregador: entregador ?? this.entregador,
      entregadorAvaliado: entregadorAvaliado ?? this.entregadorAvaliado,
    );
  }
}
