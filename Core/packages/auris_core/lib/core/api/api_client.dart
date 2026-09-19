import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_endpoints.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 35), // Senior Fix: Subido a 35s para resolvers lentos
        receiveTimeout: const Duration(seconds: 90), // Senior Fix: Subido a 90s para streams de datos largos
        headers: {
          'Accept': 'application/json',
          // Senior Web Fix: No definimos Content-Type global para evitar Preflight (OPTIONS) innecesarios en GET.
          // Solo se incluirá en POST/PUT/DELETE cuando sea necesario.
        },
      ),
    );

    _dio.interceptors.add(_apiResponseInterceptor());
    if (kDebugMode && !kIsWeb) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: false, 
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }
  }

  Interceptor _apiResponseInterceptor() {
    return InterceptorsWrapper(
      onResponse: (response, handler) {
        // Senior Fix: Desactivamos el desempaquetado automático de 'success' 
        // para evitar rechazar respuestas legítimas de microservicios que no 
        // usan el wrapper {success: true, data: ...} de forma estricta.
        handler.next(response);
      },
      onError: (error, handler) {
        if (error.response?.data is Map<String, dynamic>) {
          final map = error.response!.data as Map<String, dynamic>;
          if (map.containsKey('message')) {
            handler.next(DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              message: map['message'] as String? ?? error.message,
            ));
            return;
          }
        }
        handler.next(error);
      },
    );
  }

  String _resolvePath(String path, String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return path;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return base + p;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      _resolvePath(path, baseUrl),
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      _resolvePath(path, baseUrl),
      data: data,
      queryParameters: queryParameters,
      options: options ?? Options(contentType: Headers.jsonContentType),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      _resolvePath(path, baseUrl),
      data: data,
      queryParameters: queryParameters,
      options: options ?? Options(contentType: Headers.jsonContentType),
      cancelToken: cancelToken,
    );
  }

  /// Abre una conexión de streaming para recibir datos fragmentados (NDJSON/SSE).
  Stream<String> getStream(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.get<ResponseBody>(
      _resolvePath(path, baseUrl),
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.stream),
    );

    if (response.data != null) {
      // Senior Fix: Transformar el stream de bytes en líneas de texto utf-8.
      // Usamos un transformador que maneja correctamente los fragmentos parciales.
      yield* response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(LineSplitter());
    }
  }
}
