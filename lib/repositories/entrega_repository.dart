import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/entrega/rota_entrega_model.dart';
import 'package:nhac/services/api_client.dart';

class EntregaRepository {
  final Dio _dio;

  EntregaRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<RotaEntregaModel> buscarRota(String pedidoId) async {
    try {
      final response = await _dio.get('/entregas/$pedidoId/rota');
      return RotaEntregaModel.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw mapException(e);
    }
  }
}
