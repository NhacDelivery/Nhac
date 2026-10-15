import 'dart:convert';

import 'package:nhac/globals/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/models/pedido/pedido_criado_response.dart';
import 'package:nhac/repositories/pedido_repository.dart';

/// A tentativa sobrevive ao fechamento da tela/app. O payload contém endereço
/// e CPF, por isso usa o armazenamento seguro já adotado para a sessão.
/// Nunca expira uma resposta incerta: só confirmação ou rejeição definitiva
/// libera outra criação. Cada conta possui uma entrada independente.
class CheckoutTentativaService {
  final FlutterSecureStorage _storage;
  final PedidoRepository _repository;
  static final Set<String> _emAndamento = {};

  CheckoutTentativaService({
    FlutterSecureStorage? storage,
    PedidoRepository? repository,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ),
       _repository = repository ?? PedidoRepository();

  String _chave(String usuarioId) =>
      'nhac_checkout_pendente:${AppConstants.apiBaseUrl}:$usuarioId';

  Future<Map<String, dynamic>?> carregar(String usuarioId) async {
    final raw = await _storage.read(key: _chave(usuarioId));
    if (raw == null) return null;
    final dados = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (dados['key'] is! String || dados['payload'] is! Map) {
      throw StateError(
        'Não foi possível recuperar a tentativa anterior. Consulte seus pedidos.',
      );
    }
    return dados;
  }

  Future<PedidoCriadoResponse> enviar(
    String usuarioId,
    CriarPedidoRequest pedido,
  ) async {
    if (!_emAndamento.add(usuarioId)) {
      throw StateError('Aguarde a confirmação do pedido.');
    }
    try {
      if (await carregar(usuarioId) != null) {
        throw StateError(
          'Verifique a tentativa anterior antes de enviar outro pedido.',
        );
      }
      final tentativa = <String, dynamic>{
        'key': const Uuid().v4(),
        'payload': pedido.toMap(),
        'carrinho': pedido.origemCarrinho,
      };
      // Se a persistência falhar, o POST não é enviado.
      await _storage.write(
        key: _chave(usuarioId),
        value: jsonEncode(tentativa),
      );
      return await _executar(usuarioId, tentativa);
    } finally {
      _emAndamento.remove(usuarioId);
    }
  }

  Future<PedidoCriadoResponse> recuperar(String usuarioId) async {
    if (!_emAndamento.add(usuarioId)) {
      throw StateError('Aguarde a confirmação do pedido.');
    }
    try {
      final tentativa = await carregar(usuarioId);
      if (tentativa == null) throw StateError('Não há tentativa pendente.');
      return await _executar(usuarioId, tentativa);
    } finally {
      _emAndamento.remove(usuarioId);
    }
  }

  Future<PedidoCriadoResponse> _executar(
    String usuarioId,
    Map<String, dynamic> tentativa,
  ) async {
    if (tentativa['pedidoId'] case final String pedidoId
        when pedidoId.isNotEmpty) {
      return PedidoCriadoResponse(pedidoId: pedidoId, replay: true);
    }
    try {
      final resposta = await _repository.recuperarTentativaCheckout(
        Map<String, dynamic>.from(tentativa['payload'] as Map),
        idempotencyKey: tentativa['key'] as String,
      );
      if (resposta.pedidoId.isEmpty) {
        throw StateError(
          'Resposta sem identificação do pedido. Verifique novamente.',
        );
      }
      tentativa['pedidoId'] = resposta.pedidoId;
      await _storage.write(
        key: _chave(usuarioId),
        value: jsonEncode(tentativa),
      );
      return resposta;
    } on CustomCheckoutException catch (e) {
      // Conflito de payload não prova que o pedido anterior deixou de existir.
      if (e.code != 'IDEMPOTENCIA_CONFLITO') await concluir(usuarioId);
      rethrow;
    }
  }

  Future<void> concluir(String usuarioId) =>
      _storage.delete(key: _chave(usuarioId));
}
