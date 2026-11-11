import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart' as dio;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_handler.dart';

class ApiClient {
  late final dio.Dio dioClient;

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String? get configurationError {
    final value = _configuredBaseUrl.trim();
    if (value.isEmpty) {
      return kReleaseMode
          ? 'Set API_BASE_URL to the public HTTPS API origin when building a release.'
          : null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme) ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'API_BASE_URL must be an absolute HTTP(S) origin without a path, query, or fragment.';
    }

    if (kReleaseMode &&
        (uri.scheme != 'https' ||
            uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1' ||
            uri.host.endsWith('.localhost'))) {
      return 'Release builds require a public HTTPS API_BASE_URL; localhost and plain HTTP are not allowed.';
    }

    return null;
  }

  static String get _baseUrl {
    final error = configurationError;
    if (error != null) {
      throw StateError(error);
    }
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    if (kReleaseMode) {
      throw StateError('Release builds require API_BASE_URL.');
    }
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';
  }

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
    return dioClient.get(path, queryParameters: queryParameters);
  }

  Future<dio.Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dioClient.post(path, data: data, queryParameters: queryParameters);
  }

  Future<dio.Response<dynamic>> patch(String path, {dynamic data}) {
    return dioClient.patch(path, data: data);
  }

  Future<dio.Response<dynamic>> put(String path, {dynamic data}) {
    return dioClient.put(path, data: data);
  }

  Future<dio.Response<dynamic>> delete(String path, {dynamic data}) {
    return dioClient.delete(path, data: data);
  }

  Future<dio.Response<dynamic>> uploadProductImage(XFile image) async {
    final fileBytes = await image.readAsBytes();

    final formData = dio.FormData.fromMap({
      'file': dio.MultipartFile.fromBytes(fileBytes, filename: image.name),
    });

    return dioClient.post(
      '/products/upload-image',
      data: formData,
      options: dio.Options(contentType: 'multipart/form-data'),
    );
  }
}

final apiClient = ApiClient();
