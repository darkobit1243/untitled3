import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import '../../widgets/chat/chat_message_bubble.dart';

class MessageDetailScreen extends StatefulWidget {
  const MessageDetailScreen({
    super.key,
    required this.listingId,
    required this.carrierId,
    required this.senderId,
    required this.isCarrierUser,
    required this.listingTitle,
  });

  final String listingId;
  final String carrierId;
  final String senderId;
  final bool isCarrierUser;
  final String listingTitle;

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final Set<String> _seenIds = {};
  bool _sending = false;

  String get _meId => widget.isCarrierUser ? widget.carrierId : widget.senderId;

  DateTime _parseCreatedAt(Map<String, dynamic> item) {
    final rawAny = item['createdAt'];
    DateTime? parsed;

    if (rawAny is DateTime) {
      parsed = rawAny;
    } else if (rawAny is int) {
      final ms = rawAny < 1000000000000 ? rawAny * 1000 : rawAny;
      parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } else if (rawAny is double) {
      final asInt = rawAny.toInt();
      final ms = asInt < 1000000000000 ? asInt * 1000 : asInt;
      parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } else {
      final raw = rawAny?.toString();
      if (raw != null) {
        final numeric = int.tryParse(raw);
        if (numeric != null) {
          final ms = numeric < 1000000000000 ? numeric * 1000 : numeric;
          parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        } else {
          parsed = DateTime.tryParse(raw);
        }
      }
    }

    final dt = parsed ?? DateTime.now();
    return dt.isUtc ? dt.toLocal() : dt;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  bool _containsPhoneNumber(String input) {
    // Detect phone-number like patterns. We intentionally keep this conservative:
    // If there are 10+ digits in total, treat it as a phone number.
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 10) return true;
    // Also catch +90 / international formats with separators
    final phoneLike = RegExp(r'(\+\d{1,3}[\s\-\(\)]*)?(\d[\s\-\(\)]*){9,}\d');
    return phoneLike.hasMatch(input);
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    apiClient.followListingMessages(widget.listingId, _handleSocketMessage);
  }

  @override
  void dispose() {
    apiClient.stopFollowingListing(widget.listingId);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSocketMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      final msgId = message['id']?.toString() ?? '';
      if (msgId.isNotEmpty && _seenIds.contains(msgId)) {
        return;
      }
      // Dedupe by id
      final existingIndex = _messages.indexWhere((m) => (m['id']?.toString() ?? '') == msgId);
      if (existingIndex != -1) {
        if (!mounted) return;
        setState(() {
          _messages[existingIndex] = message;
          if (msgId.isNotEmpty) _seenIds.add(msgId);
        });
        return;
      }
      // Dedupe by sender/content for optimistic
      final sender = message['senderId']?.toString();
      final content = message['content']?.toString();
      final tempIndex = _messages.indexWhere((m) =>
          (m['id']?.toString() ?? '').startsWith('local-') &&
          m['senderId']?.toString() == sender &&
          m['content']?.toString() == content);
      if (tempIndex != -1) {
        if (!mounted) return;
        setState(() {
          _messages[tempIndex] = message;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _messages = List.from(_messages)..add(message);
        final id = message['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _seenIds.add(id);
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await apiClient.fetchMessages(widget.listingId);
      if (!mounted) return;
      _seenIds
        ..clear()
        ..addAll(data.map((m) => m['id']?.toString() ?? '').where((id) => id.isNotEmpty));
      setState(() {
        _messages = data;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesajlar yüklenemedi.')),
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_containsPhoneNumber(text)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon numarası paylaşımı yasaktır.')),
      );
      return;
    }

    if (_sending) return;
    setState(() => _sending = true);

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = <String, dynamic>{
      'id': localId,
      'senderId': _meId,
      'content': text,
      // Use UTC ISO to avoid timezone ambiguity across clients/server.
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _messages = List.from(_messages)..add(optimistic);
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final senderId = await apiClient.getCurrentUserId();
      final message = await apiClient.sendMessage(
        listingId: widget.listingId,
        content: text,
        carrierId: widget.carrierId,
        senderId: senderId,
      );
      final id = message['id']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        // Replace optimistic local message when server confirms.
        final localIndex = _messages.indexWhere((m) => (m['id']?.toString() ?? '') == localId);
        if (localIndex != -1) {
          _messages[localIndex] = message;
        }

        // If socket already delivered it, avoid adding a duplicate.
        if (id.isNotEmpty && _seenIds.contains(id)) {
          final existingIndex = _messages.indexWhere((m) => (m['id']?.toString() ?? '') == id);
          if (existingIndex != -1) {
            _messages[existingIndex] = message;
          }
          return;
        }

        final existingIndex = id.isEmpty ? -1 : _messages.indexWhere((m) => (m['id']?.toString() ?? '') == id);
        if (existingIndex != -1) {
          _messages[existingIndex] = message;
        } else {
          _messages.add(message);
        }
        if (id.isNotEmpty) {
          _seenIds.add(id);
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Remove optimistic message on failure.
      setState(() {
        _messages.removeWhere((m) => (m['id']?.toString() ?? '') == localId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.listingTitle)),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: BiTasiColors.backgroundGrey,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Henüz mesaj yok. İlk mesajı sen yazabilirsin.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final item = _messages[index];
                            final isMe = item['senderId']?.toString() == _meId;
                            final content = item['content']?.toString() ?? '';
                            if (content.trim().isEmpty) return const SizedBox.shrink();
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: ChatMessageBubble(
                                content: content,
                                isMe: isMe,
                                createdAt: _parseCreatedAt(item),
                              ),
                            );
                          },
                        ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz…',
                            filled: true,
                            fillColor: BiTasiColors.backgroundGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        width: 44,
                        child: Material(
                          color: _sending ? theme.disabledColor : BiTasiColors.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _sending ? null : _sendMessage,
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Telefon numarası paylaşımı yasaktır.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
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
