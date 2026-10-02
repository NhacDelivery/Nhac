import 'package:nhac/services/shared_get.dart';
import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/entrega/rota_entrega_model.dart';
import 'package:nhac/services/api_client.dart';

class EntregaRepository {
  final Dio _dio;

  EntregaRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  void invalidarRota(String pedidoId) =>
      SharedGet.forClient(_dio).invalidatePath('/entregas/$pedidoId/rota');

  Future<RotaEntregaModel> buscarRota(String pedidoId) async {
    try {
      final response = await SharedGet.forClient(_dio).get(
          _dio, '/entregas/$pedidoId/rota',
          validity: const Duration(minutes: 15));
      return RotaEntregaModel.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<PontoCoordenadaModel?> buscarLocalizacaoEntregador(
      String pedidoId) async {
    try {
      final response = await SharedGet.forClient(_dio).get(
          _dio, '/entregas/$pedidoId/localizacao-entregador',
          validity: const Duration(seconds: 30));
      if (response.statusCode == 204 || response.data == null) return null;
      return PontoCoordenadaModel.fromMap(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw mapException(e);
    }
  }
}
