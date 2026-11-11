import '../../core/network/api_client.dart';
import 'instagram_redirect_models.dart';

class InstagramRedirectApi {
  Future<InstagramToolsData> getTools() async {
    final response = await apiClient.get('/instagram-tools/me');
    return InstagramToolsData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<InstagramToolsData> saveConfig(InstagramConfig config) async {
    final response = await apiClient.put(
      '/instagram-tools/me',
      data: {
        'is_enabled': config.isEnabled,
        'trigger_keywords': config.triggerKeywords,
        'reply_text': config.replyText,
      },
    );
    return InstagramToolsData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> connect() async {
    await apiClient.post('/instagram-tools/connect');
  }
}

final instagramRedirectApi = InstagramRedirectApi();
