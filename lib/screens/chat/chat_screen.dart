import 'package:flutter/material.dart';

import '../../models/message_model.dart';
import '../../services/chat_api_service.dart';
import '../../services/chat_socket_service.dart';
import '../../widgets/chat_message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.senderId,
    required this.carrierId,
    required this.isCarrierUser,
  });

  final String listingId;
  final String listingTitle;
  final String senderId;
  final String carrierId;
  final bool isCarrierUser;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  List<MessageModel> _messages = [];
  final Set<String> _seenIds = {};

  String get _currentUserId => widget.isCarrierUser ? widget.carrierId : widget.senderId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    setState(() => _loading = true);
    try {
      // load history
      final history = await ChatApiService.instance.getMessages(widget.listingId);
      if (!mounted) return;
      _seenIds
        ..clear()
        ..addAll(history.map((m) => m.id));
      setState(() => _messages = history);
      _scrollToBottom();

      // connect socket and listen
      await ChatSocketService.instance.connect();
      ChatSocketService.instance.listenListingMessages(widget.listingId, (data) {
        final msg = MessageModel.fromJson(data);
        if (msg.content.isEmpty || msg.id.isEmpty) return;
        if (_seenIds.contains(msg.id)) {
          // replace if exists
          final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
          if (existingIndex != -1) {
            if (!mounted) return;
            setState(() {
              _messages[existingIndex] = msg;
            });
            _scrollToBottom();
            return;
          }
          return;
        }
        // Dedupe: replace optimistic local copy if same sender/content
        final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
        if (existingIndex != -1) {
          if (!mounted) return;
          setState(() {
            _messages[existingIndex] = msg;
          });
          _seenIds.add(msg.id);
          _scrollToBottom();
          return;
        }
        final tempIndex = _messages.indexWhere((m) =>
            m.id.startsWith('local-') &&
            m.senderId == msg.senderId &&
            m.content == msg.content);
        if (tempIndex != -1) {
          if (!mounted) return;
          setState(() {
            _messages[tempIndex] = msg;
          });
          _seenIds.add(msg.id);
          _scrollToBottom();
          return;
        }
        if (!mounted) return;
        setState(() => _messages = List.from(_messages)..add(msg));
        _seenIds.add(msg.id);
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesajlar yüklenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final socketConnected = ChatSocketService.instance.connected;
      if (socketConnected) {
        // emit over socket; server yayınlayacak
        ChatSocketService.instance.emitMessage(
          listingId: widget.listingId,
          senderId: widget.senderId,
          carrierId: widget.carrierId,
          content: trimmed,
        );
        // socket yayını gelene kadar bekle; ekstra ekleme yok
      } else {
        // socket yoksa REST gönder
        await ChatApiService.instance.sendMessage(
          listingId: widget.listingId,
          content: trimmed,
          senderId: widget.senderId,
          carrierId: widget.carrierId,
        );
        // REST dönen mesajı ekle
        // Yeniden çekmek yerine tek çağrıyla al
        final history = await ChatApiService.instance.getMessages(widget.listingId);
        if (!mounted) return;
        _seenIds
          ..clear()
          ..addAll(history.map((m) => m.id));
        setState(() => _messages = history);
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderilemedi: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _sendText(text);
  }

  Future<void> _sendQuick(String text) async {
    await _sendText(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    ChatSocketService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listingTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == _currentUserId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ChatMessageBubble(
                          content: msg.content,
                          isMe: isMe,
                          createdAt: msg.createdAt,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => _sendQuick('yoldayım'),
                          child: const Text('yoldayım'),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => _sendQuick('10 dk gecikeceğim'),
                          child: const Text('10 dk gecikeceğim'),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => _sendQuick('adrese geldim'),
                          child: const Text('adrese geldim'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz...',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


