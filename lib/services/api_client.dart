import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/utils/app_exceptions.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:nhac/globals/router.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio dio;
  String? _cachedToken;

  factory ApiClient() {
    return _instance;
  }

  void atualizarTokenCache(String? novoToken) {
    _cachedToken = novoToken;
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          _cachedToken ??= await SessionStorageService().obterToken();
          final token = _cachedToken;
          if (token != null && !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('🌍 [REQ HTTP] ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
              '✅ [RES HTTP] ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          debugPrint(
              '❌ [ERR HTTP] Status: ${e.response?.statusCode} | Rota: ${e.requestOptions.path}');

          final responseData = e.response?.data;
          final statusCode = e.response?.statusCode;
          final defaultMessage =
              responseData?['message'] ?? 'Erro desconhecido';

          if (statusCode == 401 &&
              !e.requestOptions.path.contains('/login') &&
              !e.requestOptions.path.contains('/auth/alterar-senha')) {
            _cachedToken = null;
            await authServiceRoteador.logout();
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: UnauthorizedException(defaultMessage),
            ));
          }

          if (responseData is Map) {
            debugPrint(
              'Erro API: status=$statusCode code=${responseData['error']}',
            );
          }

          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.unknown ||
              e.type == DioExceptionType.cancel) {
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: ServerException(
                  "Sem conexão com a internet ou servidor indisponível. Verifique sua rede e tente novamente."),
            ));
          }

          // Tratamento por Status Code
          Exception customError;
          switch (statusCode) {
            case 400:
              // Verifica se possui o detalhamento de campos
              if (responseData != null &&
                  responseData is Map &&
                  responseData.containsKey('details')) {
                customError = ValidationException(
                    defaultMessage, responseData['details']);
              } else {
                customError = BusinessRuleException(defaultMessage);
              }
              break;
            case 401:
              customError = UnauthorizedException(defaultMessage);
              break;
            case 403:
              customError = ForbiddenException(defaultMessage);
              break;
            case 409:
              customError = BusinessRuleException(defaultMessage);
              break;
            case 404:
              customError = NotFoundException(defaultMessage);
              break;
            case 422:
              customError = BusinessRuleException(defaultMessage);
              break;
            case 429:
              customError = TooManyRequestsException();
              break;
            case 500:
            default:
              customError = ServerException();
              break;
          }

          return handler.reject(DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: customError,
          ));
        },
      ),
    );
  }
}
