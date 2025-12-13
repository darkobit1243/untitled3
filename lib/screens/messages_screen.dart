import 'dart:math';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
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

  void _socketStatusListener(bool connected) {
    if (!mounted) return;
    setState(() {
      _socketConnected = connected;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadThreads();
    apiClient.getPreferredRole().then((value) {
      if (!mounted) return;
      setState(() {
        _role = value;
      });
    });
    _loadContacts();
    apiClient.addSocketStatusListener(_socketStatusListener);
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
                      final userIsCarrier = _role == 'carrier';
                      final title = 'Gönderi ${listingId.substring(0, min(4, listingId.length))}';
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
                          final userId = await apiClient.getCurrentUserId();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessageDetailScreen(
                                listingId: listingId,
                                carrierId: carrierId,
                                senderId: userId,
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Bu göndericinin aktif gönderisi bulunmuyor.')),
                                );
                                return;
                              }

                              if (!mounted) return;

                              showDialog(
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderiler alınamadı.')),
                              );
                            }
                          } else {
                            // For senders messaging carriers
                            Navigator.push(
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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    apiClient.followListingMessages(widget.listingId, _handleSocketMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSocketMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      setState(() {
        _messages = List.from(_messages)..add(message);
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
      setState(() {
        _messages = data;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesajlar yüklenemedi.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      final senderId = await apiClient.getCurrentUserId();
      final message = await apiClient.sendMessage(
        listingId: widget.listingId,
        content: text,
        carrierId: widget.carrierId,
        senderId: senderId,
        fromCarrier: widget.isCarrierUser,
      );
      setState(() {
        _messages.add(message);
      });
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj gönderilemedi.')),
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
                      final fromCarrier = item['fromCarrier'] == true;
                      return Align(
                        alignment: fromCarrier ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: fromCarrier ? Colors.white : TrustShipColors.primaryBlue.withOpacity(0.2),
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
            child: Row(
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
          ),
        ],
      ),
    );
  }
}

