import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_handler.dart';

class ApiClient {
  late final dio.Dio dioClient;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.69.241.119:8000',
  );

  ApiClient() {
    dioClient = dio.Dio(
      dio.BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dioClient.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = Supabase.instance.client.auth.currentSession;
          final token = session?.accessToken;

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (error, handler) {
          ErrorHandler.handle(error);
          handler.next(error);
        },
      ),
    );
  }

  Future<dio.Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return dioClient.get(
      path,
      queryParameters: queryParameters,
    );
  }

  Future<dio.Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dioClient.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<dio.Response<dynamic>> patch(
    String path, {
    dynamic data,
  }) {
    return dioClient.patch(
      path,
      data: data,
    );
  }

  Future<dio.Response<dynamic>> put(
    String path, {
    dynamic data,
  }) {
    return dioClient.put(
      path,
      data: data,
    );
  }

  Future<dio.Response<dynamic>> delete(
    String path, {
    dynamic data,
  }) {
    return dioClient.delete(
      path,
      data: data,
    );
  }

  Future<dio.Response<dynamic>> uploadProductImage(String filePath) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;

    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    return dioClient.post(
      '/products/upload-image',
      data: formData,
      options: dio.Options(
        contentType: 'multipart/form-data',
      ),
    );
  }
}

final apiClient = ApiClient();