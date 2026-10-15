import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

Future<void> main() async {
  final client = HttpClient();
  final baseUrl = 'backend-nhac.cloud.run';
  
  try {
    final uuid = 'test-uuid-${DateTime.now().millisecondsSinceEpoch}';
    final email = 'test_${DateTime.now().millisecondsSinceEpoch}@nhac.com';
    
    debugPrint('1. Registering user...');
    final regUri = Uri.https(baseUrl, '/api/v1/auth/registrar');
    final regRequest = await client.postUrl(regUri);
    regRequest.headers.contentType = ContentType.json;
    
    final regBody = {
      'id': uuid,
      'nome': 'Test User',
      'email': email,
      'telefone': '11999999999',
      'senha': 'password123'
    };
    
    regRequest.write(jsonEncode(regBody));
    final regResponse = await regRequest.close();
    final regResponseBody = await regResponse.transform(utf8.decoder).join();
    debugPrint('Reg status: ${regResponse.statusCode}');
    debugPrint('Reg body: $regResponseBody');
    
    if (regResponse.statusCode != 201) {
      debugPrint('Failed to register user.');
      return;
    }
    
    final regData = jsonDecode(regResponseBody) as Map<String, dynamic>;
    final token = regData['token'] as String;
    final userId = regData['usuarioId'] as String;
    
    debugPrint('2. Adding address...');
    final addrUri = Uri.https(baseUrl, '/api/v1/usuarios/$userId/enderecos');
    final addrRequest = await client.postUrl(addrUri);
    addrRequest.headers.contentType = ContentType.json;
    addrRequest.headers.set('Authorization', 'Bearer $token');
    
    final addrBody = {
      'rua': 'Rua do Teste',
      'numero': '123',
      'bairro': 'Centro',
      'cidade': 'Sao Paulo',
      'estado': 'SP',
      'cep': '01001-000',
      'complemento': 'Apt 1',
      'isPadrao': true
    };
    
    addrRequest.write(jsonEncode(addrBody));
    final addrResponse = await addrRequest.close();
    debugPrint('Add address status: ${addrResponse.statusCode}');
    
    debugPrint('3. Getting addresses...');
    final getUri = Uri.https(baseUrl, '/api/v1/usuarios/$userId/enderecos');
    final getRequest = await client.getUrl(getUri);
    getRequest.headers.set('Authorization', 'Bearer $token');
    
    final getResponse = await getRequest.close();
    final getResponseBody = await getResponse.transform(utf8.decoder).join();
    debugPrint('Get addresses status: ${getResponse.statusCode}');
    debugPrint('Get addresses body: $getResponseBody');
    
  } catch (e) {
    debugPrint('Error: $e');
  } finally {
    client.close();
  }
}
