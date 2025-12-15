import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message_model.dart';
import 'api_client.dart';

class ChatApiService {
  ChatApiService._();
  static final ChatApiService instance = ChatApiService._();

  Future<List<MessageModel>> getMessages(String listingId) async {
    final resp = await http.get(
      Uri.parse('${apiClient.baseUrl}/messages/$listingId'),
      headers: apiClient.authHeaders(),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Mesajlar alınamadı: ${resp.body}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MessageModel> sendMessage({
    required String listingId,
    required String content,
    required String senderId,
    required String carrierId,
  }) async {
    final resp = await http.post(
      Uri.parse('${apiClient.baseUrl}/messages'),
      headers: apiClient.authHeaders(),
      body: jsonEncode({
        'listingId': listingId,
        'senderId': senderId,
        'carrierId': carrierId,
        'content': content,
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Mesaj gönderilemedi: ${resp.body}');
    }
    return MessageModel.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}


