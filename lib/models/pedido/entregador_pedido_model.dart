class EntregadorPedidoModel {
  final String nome;
  final String? fotoUrl;
  final String? tipoVeiculo;
  final String? modeloVeiculo;
  final String? corVeiculo;
  final String? placaVeiculo;
  final double? avaliacaoMedia;
  final int? totalAvaliacoes;

  const EntregadorPedidoModel({
    required this.nome,
    this.fotoUrl,
    this.tipoVeiculo,
    this.modeloVeiculo,
    this.corVeiculo,
    this.placaVeiculo,
    this.avaliacaoMedia,
    this.totalAvaliacoes,
  });

  factory EntregadorPedidoModel.fromMap(Map<String, dynamic> map) {
    return EntregadorPedidoModel(
      nome: map['nome']?.toString() ?? 'Entregador',
      fotoUrl: map['fotoUrl']?.toString(),
      tipoVeiculo: map['tipoVeiculo']?.toString(),
      modeloVeiculo: map['modeloVeiculo']?.toString(),
      corVeiculo: map['corVeiculo']?.toString(),
      placaVeiculo: map['placaVeiculo']?.toString(),
      avaliacaoMedia: map['avaliacaoMedia'] == null
          ? null
          : num.tryParse(map['avaliacaoMedia'].toString())?.toDouble(),
      totalAvaliacoes: map['totalAvaliacoes'] == null
          ? null
          : num.tryParse(map['totalAvaliacoes'].toString())?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'fotoUrl': fotoUrl,
    'tipoVeiculo': tipoVeiculo,
    'modeloVeiculo': modeloVeiculo,
    'corVeiculo': corVeiculo,
    'placaVeiculo': placaVeiculo,
    'avaliacaoMedia': avaliacaoMedia,
    'totalAvaliacoes': totalAvaliacoes,
  };
}
