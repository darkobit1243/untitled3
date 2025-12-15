// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../services/chat_socket_service.dart';
import '../theme/trustship_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _contacts = [];
  bool _contactsLoading = true;
  String _role = 'sender';
  bool _socketConnected = true;
  String? _currentUserId;
  late final void Function(bool) _socketStatusListener;
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _socketStatusListener = (connected) {
      if (!mounted) return;
      setState(() {
        _socketConnected = connected;
      });
    };
    _loadThreads();
    apiClient.getPreferredRole().then((value) {
      if (!mounted) return;
      setState(() {
        _role = value;
      });
    });
    _loadContacts();
    apiClient.addSocketStatusListener(_socketStatusListener);
    _setupUserListener();
  }

  Future<void> _setupUserListener() async {
    try {
      final uid = await apiClient.getCurrentUserId();
      _currentUserId = uid;
      ChatSocketService.instance.connect(); // ensure socket connected
      ChatSocketService.instance.listenUserMessages(uid, (data) {
        // Yeni mesaj geldi, thread list'ini tazele
        _loadThreads();
        // Eğer gelen mesajı şu anki kullanıcı göndermişse bildirim gösterme
        final senderId = data['senderId']?.toString() ?? '';
        if (senderId.isNotEmpty && senderId == _currentUserId) return;
        if (!mounted) return;
        appSettings.getNotificationsEnabled().then((enabled) {
          if (!mounted || !enabled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yeni mesajın var')),
          );
        });
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _fetchAndCacheUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) return;
    try {
      final data = await apiClient.fetchUserById(userId);
      final name = data['fullName']?.toString() ?? data['email']?.toString() ?? userId;
      if (!mounted) return;
      setState(() {
        _userNameCache[userId] = name;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadThreads() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await apiClient.fetchThreads();
      if (!mounted) return;
      setState(() {
        _threads = data;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj dizileri alınamadı.')),
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _contactsLoading = true;
    });
    try {
      final data = await apiClient.fetchContacts();
      if (!mounted) return;
      setState(() {
        _contacts = data;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kişi listesi alınamadı.')),
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() {
        _contactsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 24,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _socketConnected ? Icons.wifi : Icons.wifi_off,
                  size: 14,
                  color: _socketConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _socketConnected ? 'Canlı' : 'Bağlantı yok',
                  style: TextStyle(
                    fontSize: 12,
                    color: _socketConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadThreads(), _loadContacts()]);
        },
        child: _loading && _contactsLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_threads.isNotEmpty)
                    ..._threads.map((thread) {
                      final time = thread['createdAt']?.toString().substring(11, 16) ?? '';
                      final listingId = thread['listingId']?.toString() ?? '';
                      final carrierId = thread['carrierId']?.toString() ?? '';
                      final senderId = thread['senderId']?.toString() ?? '';
                      final userIsCarrier = _role == 'carrier';
                      final otherUserId = userIsCarrier ? senderId : carrierId;
                      final cachedName = _userNameCache[otherUserId];
                      final displayName = cachedName ??
                          (otherUserId.isNotEmpty ? 'Kullanıcı ${otherUserId.substring(0, min(4, otherUserId.length))}' : 'Kullanıcı');
                      if (cachedName == null && otherUserId.isNotEmpty) {
                        _fetchAndCacheUserName(otherUserId);
                      }
                      final title = '$displayName · Gönderi ${listingId.substring(0, min(4, listingId.length))}';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        leading: CircleAvatar(
                          backgroundColor: TrustShipColors.primaryBlue.withOpacity(0.2),
                          child: const Icon(Icons.chat, color: TrustShipColors.primaryBlue),
                        ),
                        title: Text(title),
                        subtitle: Text(thread['lastMessage']?.toString() ?? ''),
                        trailing: Text(time),
                        onTap: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessageDetailScreen(
                                listingId: listingId,
                                carrierId: carrierId,
                                senderId: senderId,
                                isCarrierUser: userIsCarrier,
                                listingTitle: title,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  if (_contacts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _role == 'carrier' ? 'Göndericiler' : 'Carrierlar',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ..._contacts.map((contact) {
                      final isCarrier = _role == 'carrier';
                      final title = isCarrier
                          ? '${contact['activeListingsCount']?.toString() ?? '0'} aktif gönderi'
                          : (contact['listingTitle']?.toString() ?? 'Yayındaki Gönderi');
                      final name = isCarrier
                          ? (contact['senderName']?.toString() ?? 'Gönderici')
                          : (contact['carrierEmail']?.toString() ?? 'Carrier');
                      final subtitle = isCarrier
                          ? (contact['senderEmail']?.toString() ?? '')
                          : title;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        leading: CircleAvatar(
                          backgroundColor: isCarrier
                              ? TrustShipColors.primaryBlue.withOpacity(0.2)
                              : TrustShipColors.primaryRed.withOpacity(0.2),
                          child: Icon(
                            isCarrier ? Icons.person_outline : Icons.local_shipping,
                            color: isCarrier ? TrustShipColors.primaryBlue : TrustShipColors.primaryRed,
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(subtitle),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final userId = await apiClient.getCurrentUserId();
                          // For carriers, we need to start a conversation with a sender
                          // For now, we'll navigate to a general message screen
                          // In a real app, you'd need to select a specific listing
                          if (isCarrier) {
                            // For carriers: Get sender's listings and show a selection dialog
                            try {
                              final senderListings = await apiClient.fetchListings();
                              final senderId = contact['senderId']?.toString() ?? '';
                              final relevantListings = senderListings.where((listing) =>
                                listing['ownerId']?.toString() == senderId
                              ).toList();

                              if (relevantListings.isEmpty) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Bu göndericinin aktif gönderisi bulunmuyor.')),
                                );
                                return;
                              }

                              if (!mounted) return;

                              showDialog(
                                // ignore: use_build_context_synchronously
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Gönderi Seçin'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: relevantListings.length,
                                      itemBuilder: (context, index) {
                                        final listing = relevantListings[index];
                                        final listingTitle = listing['title']?.toString() ?? 'Gönderi ${index + 1}';
                                        return ListTile(
                                          title: Text(listingTitle),
                                          subtitle: Text('ID: ${listing['id']}'),
                                          onTap: () {
                                            Navigator.pop(context); // Close dialog
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => MessageDetailScreen(
                                                  listingId: listing['id']?.toString() ?? '',
                                                  carrierId: userId,
                                                  senderId: senderId,
                                                  isCarrierUser: true,
                                                  listingTitle: listingTitle,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('İptal'),
                                    ),
                                  ],
                                ),
                              );
                            } catch (_) {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderiler alınamadı.')),
                              );
                            }
                          } else {
                            // For senders messaging carriers
                            Navigator.push(
                              // ignore: use_build_context_synchronously
                              context,
                              MaterialPageRoute(
                                builder: (_) => MessageDetailScreen(
                                  listingId: contact['listingId']?.toString() ?? '',
                                  carrierId: contact['carrierId']?.toString() ?? '',
                                  senderId: userId,
                                  isCarrierUser: false,
                                  listingTitle: title,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }),
                  ],
                  if (_threads.isEmpty && _contacts.isEmpty && !_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Henüz görünür bir mesaj yok. Teklifleri bekle.'),
                    ),
                ],
              ),
      ),
    );
  }
}

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
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final Set<String> _seenIds = {};

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
        // If socket already delivered it, avoid adding a duplicate.
        if (id.isNotEmpty && _seenIds.contains(id)) {
          final existingIndex = _messages.indexWhere((m) => (m['id']?.toString() ?? '') == id);
          if (existingIndex != -1) {
            _messages[existingIndex] = message;
          }
          return;
        }

        final existingIndex = id.isEmpty
            ? -1
            : _messages.indexWhere((m) => (m['id']?.toString() ?? '') == id);
        if (existingIndex != -1) {
          _messages[existingIndex] = message;
        } else {
          _messages.add(message);
        }
        if (id.isNotEmpty) {
          _seenIds.add(id);
        }
      });
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.listingTitle)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[index];
                      final meId = widget.isCarrierUser ? widget.carrierId : widget.senderId;
                      final isMe = item['senderId']?.toString() == meId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? TrustShipColors.primaryBlue.withOpacity(0.2) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(item['content']?.toString() ?? ''),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Mesaj yaz...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: TrustShipColors.primaryBlue),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Telefon numarası paylaşımı yasaktır.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

