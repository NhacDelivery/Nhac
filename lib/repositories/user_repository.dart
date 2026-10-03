import 'package:nhac/services/shared_get.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/globals/exceptions.dart';

class UserRepository {
  final _dio = ApiClient().dio;

  Future<String> enviarFotoPerfil(File imagem) async {
    final tamanho = await imagem.length();
    if (tamanho == 0 || tamanho > 5 * 1024 * 1024) {
      throw Exception('A imagem deve ter entre 1 byte e 5 MB.');
    }
    final bytes = await imagem.readAsBytes();
    final jpeg = bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final png = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    final webp = bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!jpeg && !png && !webp) {
      throw Exception('Envie uma imagem JPG, PNG ou WEBP.');
    }
    final formato = jpeg
        ? 'jpeg'
        : png
            ? 'png'
            : 'webp';
    final extensao = jpeg ? 'jpg' : formato;
    try {
      final resposta = await _dio.post(
        '/uploads/imagem',
        data: FormData.fromMap({
          'pasta': 'usuarios',
          'arquivo': MultipartFile.fromBytes(bytes,
              filename: 'perfil.$extensao',
              contentType: DioMediaType('image', formato)),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      return resposta.data['url'] as String;
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<UsuarioModel?> buscarUsuario(String id) async {
    try {
      final response =
          await SharedGet.forClient(_dio).get(_dio, '/usuarios/$id');
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
      String id, Map<String, dynamic> dados) async {
    try {
      await _dio.put('/usuarios/$id', data: dados);
    } catch (e) {
      debugPrint("Erro ao atualizar utilizador na API: $e");
      throw mapException(e);
    }
  }
}
