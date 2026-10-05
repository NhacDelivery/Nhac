import 'package:nhac/services/shared_get.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:nhac/services/image_upload_service.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/globals/exceptions.dart';

class UserRepository {
  final _dio = ApiClient().dio;

  Future<String> enviarFotoPerfil(File imagem) async {
    return ImageUploadService().enviar(XFile(imagem.path));
  }

  Future<UsuarioModel?> buscarUsuario(String id) async {
    try {
      final response = await SharedGet.forClient(
        _dio,
      ).get(_dio, '/usuarios/$id');
      if (response.statusCode == 200 && response.data != null) {
        return UsuarioModel.fromMap(response.data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint("Erro ao buscar utilizador na API: ${e.message}");
      throw mapException(e);
    }
  }

  Future<void> salvarUsuario(UsuarioModel usuario) async {
    try {
      await _dio.post('/usuarios', data: usuario.toMap());
    } catch (e) {
      debugPrint("Erro ao salvar utilizador na API: $e");
      throw mapException(e);
    }
  }

  Future<void> atualizarDadosUsuario(
    String id,
    Map<String, dynamic> dados,
  ) async {
    try {
      await _dio.put('/usuarios/$id', data: dados);
    } catch (e) {
      debugPrint("Erro ao atualizar utilizador na API: $e");
      throw mapException(e);
    }
  }
}
