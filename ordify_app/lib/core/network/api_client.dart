import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_handler.dart';

class ApiClient {
  late final Dio dio;

  static const String _baseUrl = 'http://192.168.1.39:8000';
  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = Supabase.instance.client.auth.currentSession;
          final token = session?.accessToken;

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) {
          ErrorHandler.handle(error);
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(String path) {
    return dio.get(path);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return dio.delete(path);
  }
}

final apiClient = ApiClient();