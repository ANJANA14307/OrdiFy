import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_handler.dart';

class ApiClient {
  late final dio.Dio dioClient;

  static const String _baseUrl = 'http://192.168.137.1:8000';

  ApiClient() {
    dioClient = dio.Dio(
      dio.BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
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

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (dio.DioException error, handler) {
          ErrorHandler.handle(error);
          return handler.next(error);
        },
      ),
    );
  }

  Future<dio.Response> get(String path) {
    return dioClient.get(path);
  }

  Future<dio.Response> post(String path, {dynamic data}) {
    return dioClient.post(path, data: data);
  }

  Future<dio.Response> patch(String path, {dynamic data}) {
    return dioClient.patch(path, data: data);
  }

  Future<dio.Response> put(String path, {dynamic data}) {
    return dioClient.put(path, data: data);
  }

  Future<dio.Response> delete(String path) {
    return dioClient.delete(path);
  }

  Future<dio.Response> uploadProductImage(String filePath) async {
    final fileName = filePath.split('/').last;

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