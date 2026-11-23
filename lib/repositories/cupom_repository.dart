import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/usuario/cupom_model.dart';
import 'package:nhac/services/api_client.dart';

class CupomRepository {
  final Dio _dio;
  CupomRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<CupomModel>> buscarCupons({String? lojaId}) async {
    try {
      final response = await _dio.get('/cupons', queryParameters: lojaId == null ? null : {'lojaId': lojaId});
      return (response.data as List)
          .map((item) => CupomModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<CupomModel> ganharBoasVindas() async {
    try {
      final response = await _dio.post('/cupons/boas-vindas');
      return CupomModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<CupomModel> validarCupom(String cupomId, double subtotal, {String? lojaId}) async {
    try {
      final response = await _dio.post('/cupons/validar', data: {
        'cupomId': cupomId,
        'subtotal': subtotal, if (lojaId != null) 'lojaId': lojaId,
      });
      return CupomModel.fromMap(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw mapException(e);
    }
  }
}
