import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import 'return_models.dart';

class ReturnsApi {
  Future<Map<String, dynamic>?> getPolicy() async {
    final response = await apiClient.get('/returns/policy');
    final policy = response.data['policy'];
    return policy is Map ? Map<String, dynamic>.from(policy) : null;
  }

  Future<Map<String, dynamic>> savePolicy(Map<String, dynamic> policy) async {
    final response = await apiClient.put('/returns/policy', data: policy);
    return Map<String, dynamic>.from(response.data['policy'] as Map);
  }

  Future<Map<String, dynamic>> getEligibility(String orderId) async {
    final response = await apiClient.get(
      '/returns/orders/$orderId/eligibility',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<ReturnRequest> createRequest(
    String orderId,
    Map<String, dynamic> request,
  ) async {
    final response = await apiClient.post(
      '/returns/orders/$orderId',
      data: request,
    );
    return ReturnRequest.fromJson(
      Map<String, dynamic>.from(response.data['return_request'] as Map),
    );
  }

  Future<List<ReturnRequest>> getReturns({String? status}) async {
    final response = await apiClient.get(
      '/returns',
      queryParameters: status == null ? null : {'status': status},
    );
    return (response.data['returns'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ReturnRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ReturnRequest> getReturn(String returnId) async {
    final response = await apiClient.get('/returns/$returnId');
    return ReturnRequest.fromJson(
      Map<String, dynamic>.from(response.data['return_request'] as Map),
    );
  }

  Future<ReturnRequest> act(
    String returnId,
    Map<String, dynamic> action,
  ) async {
    final response = await apiClient.post(
      '/returns/$returnId/actions',
      data: action,
    );
    return ReturnRequest.fromJson(
      Map<String, dynamic>.from(response.data['return_request'] as Map),
    );
  }

  Future<String> uploadPhoto(XFile image) async {
    final response = await apiClient.uploadProductImage(image);
    final url = response.data['secure_url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Image upload did not return a secure URL');
    }
    return url;
  }
}

final returnsApi = ReturnsApi();

String returnsErrorMessage(Object error) {
  if (error is DioException) {
    final responseData = error.response?.data;
    if (responseData is Map && responseData['detail'] != null) {
      final detail = responseData['detail'];
      if (detail is List) {
        return detail
            .whereType<Map>()
            .map((item) => item['msg']?.toString())
            .whereType<String>()
            .join('\n');
      }
      return detail.toString();
    }
  }
  return error.toString();
}
