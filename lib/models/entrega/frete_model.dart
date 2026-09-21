class FreteModel {
  final double valor;
  final int tempoEstimadoMinutos;

  const FreteModel({
    required this.valor,
    required this.tempoEstimadoMinutos,
  });

  factory FreteModel.fromMap(Map<String, dynamic> map) {
    return FreteModel(
      valor: num.tryParse(map['valor']?.toString() ?? '0')?.toDouble() ?? 0,
      tempoEstimadoMinutos:
          int.tryParse(map['tempoEstimadoMinutos']?.toString() ?? '0') ?? 0,
    );
  }
}
