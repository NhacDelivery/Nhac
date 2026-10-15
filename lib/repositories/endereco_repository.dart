import 'package:nhac/services/shared_get.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/services/api_client.dart';

class EnderecoRepository {
  final _dio = ApiClient().dio;

  Future<List<EnderecoModel>> buscarEnderecos(String usuarioId) async {
    try {
      final response = await SharedGet.forClient(_dio)
          .get(_dio, '/usuarios/$usuarioId/enderecos');

      final List<dynamic> dados = response.data;
      return dados.map((map) => EnderecoModel.fromMap(map)).toList();
    } catch (e) {
      throw Exception("Erro ao buscar endereços: $e");
    }
  }

  Future<void> adicionarEndereco(
      String usuarioId, EnderecoModel endereco) async {
    try {
      await _dio.post('/usuarios/$usuarioId/enderecos', data: endereco.toMap());
    } catch (e) {
      throw Exception("Erro ao adicionar endereço: $e");
    }
  }

  Future<void> removerEndereco(String usuarioId, String enderecoId) async {
    try {
      await _dio.delete('/usuarios/$usuarioId/enderecos/$enderecoId');
    } catch (e) {
      throw Exception("Erro ao remover endereço: $e");
    }
  }

  Future<void> atualizarEndereco(
      String usuarioId, String enderecoId, EnderecoModel endereco) async {
    try {
      await _dio.put('/usuarios/$usuarioId/enderecos/$enderecoId',
          data: endereco.toMap());
    } catch (e) {
      throw Exception("Erro ao atualizar endereço: $e");
    }
  }
}
