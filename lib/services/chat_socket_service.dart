// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api_client.dart';

class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  IO.Socket? _socket;
  bool get connected => _socket?.connected == true;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;
    final token = await apiClient.getAuthToken();
    _socket = IO.io(
      apiClient.baseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'extraHeaders': {'Authorization': 'Bearer $token'},
        'forceNew': true,
      },
    );
    _socket?.connect();
  }

  void listenListingMessages(String conversationId, void Function(Map<String, dynamic>) onMessage) {
    _socket?.on('message_$conversationId', (data) {
      if (data is Map<String, dynamic>) {
        onMessage(data);
      }
    });
  }

  void listenUserMessages(String userId, void Function(Map<String, dynamic>) onMessage) {
    _socket?.on('message_user_$userId', (data) {
      if (data is Map<String, dynamic>) {
        onMessage(data);
      }
    });
  }

  void offUserMessages(String userId) {
    _socket?.off('message_user_$userId');
  }

  void emitMessage({
    required String listingId,
    required String senderId,
    required String carrierId,
    required String content,
  }) {
    if (!connected) return;
    _socket?.emit('sendMessage', {
      'listingId': listingId,
      'senderId': senderId,
      'carrierId': carrierId,
      'content': content,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }
}


