import '../../core/network/api_client.dart';
import 'whatsapp_order_models.dart';

class WhatsAppOrdersApi {
  Future<WhatsAppConfig> getConfig() async {
    final response = await apiClient.get('/whatsapp-orders/settings');
    final data = Map<String, dynamic>.from(response.data as Map);
    return WhatsAppConfig.fromJson(
      Map<String, dynamic>.from(data['config'] as Map),
    );
  }

  Future<WhatsAppConfig> saveConfig({
    required String phoneNumber,
    required String phoneNumberId,
    required bool isEnabled,
  }) async {
    final response = await apiClient.put(
      '/whatsapp-orders/settings',
      data: {
        'phone_number': phoneNumber,
        'phone_number_id': phoneNumberId,
        'is_enabled': isEnabled,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return WhatsAppConfig.fromJson(
      Map<String, dynamic>.from(data['config'] as Map),
    );
  }

  Future<WhatsAppConfig> saveTemplates(MessageTemplate templates) async {
    final response = await apiClient.put(
      '/whatsapp-orders/templates',
      data: {
        'confirmation': templates.confirmation,
        'shipped': templates.shipped,
        'delivered': templates.delivered,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return WhatsAppConfig.fromJson(
      Map<String, dynamic>.from(data['config'] as Map),
    );
  }

  Future<List<SocialOrder>> getOrders() async {
    final response = await apiClient.get('/whatsapp-orders');
    final data = Map<String, dynamic>.from(response.data as Map);
    final orders = data['orders'];
    if (orders is! List) return [];
    return orders
        .whereType<Map>()
        .map((order) => SocialOrder.fromJson(Map<String, dynamic>.from(order)))
        .toList();
  }

  Future<SocialOrder> getOrder(String id) async {
    final response = await apiClient.get('/whatsapp-orders/$id');
    final data = Map<String, dynamic>.from(response.data as Map);
    return SocialOrder.fromJson(
      Map<String, dynamic>.from(data['order'] as Map),
    );
  }

  Future<void> actOnOrder(
    String id, {
    required String action,
    bool customerConfirmed = false,
  }) async {
    await apiClient.post(
      '/whatsapp-orders/$id/actions',
      data: {'action': action, 'customer_confirmed': customerConfirmed},
    );
  }
}

final whatsappOrdersApi = WhatsAppOrdersApi();
