import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/services/api_client.dart';

/// Upload canônico de imagens de usuário (perfil e publicações).
class ImageUploadService {
  final Dio _dio;
  ImageUploadService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<String> enviar(XFile imagem) async {
    final tamanho = await imagem.length();
    if (tamanho == 0 || tamanho > 5 * 1024 * 1024) {
      throw Exception('A imagem deve ter entre 1 byte e 5 MB.');
    }
    final bytes = await imagem.readAsBytes();
    final jpeg = bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final png = bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47;
    final webp = bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!jpeg && !png && !webp) {
      throw Exception('Envie uma imagem JPG, PNG ou WEBP.');
    }
    final formato = jpeg ? 'jpeg' : png ? 'png' : 'webp';
    try {
      final resposta = await _dio.post('/uploads/imagem',
        data: FormData.fromMap({
          'pasta': 'usuarios',
          'arquivo': MultipartFile.fromBytes(bytes,
            filename: 'imagem.${jpeg ? 'jpg' : formato}',
            contentType: DioMediaType('image', formato)),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      final url = resposta.data['url'] as String;
      if (!url.startsWith('https://')) throw Exception('O upload não retornou uma imagem segura.');
      return url;
    } catch (e) { throw mapException(e); }
  }
}
