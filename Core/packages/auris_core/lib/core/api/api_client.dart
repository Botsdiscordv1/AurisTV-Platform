import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_endpoints.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10), 
        receiveTimeout: const Duration(seconds: 60), 
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
        if (response.data is Map<String, dynamic>) {
          final map = response.data as Map<String, dynamic>;
          if (map.containsKey('success')) {
            if (map['success'] == true) {
              response.data = map['data'];
              handler.next(response);
            } else {
              handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                  message: map['message'] as String? ??
                      (map['error'] is Map ? (map['error'] as Map)['message'] as String? : null) ??
                      'Unknown error',
                ),
              );
            }
            return;
          }
        }
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
  }) {
    return _dio.get<T>(
      _resolvePath(path, baseUrl),
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    Options? options,
  }) {
    return _dio.post<T>(
      _resolvePath(path, baseUrl),
      data: data,
      queryParameters: queryParameters,
      options: options ?? Options(contentType: Headers.jsonContentType),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? baseUrl,
    Options? options,
  }) {
    return _dio.delete<T>(
      _resolvePath(path, baseUrl),
      data: data,
      queryParameters: queryParameters,
      options: options ?? Options(contentType: Headers.jsonContentType),
    );
  }
}
