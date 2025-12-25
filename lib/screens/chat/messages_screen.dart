import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import 'message_detail_screen.dart';

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

  late final void Function(bool) _socketStatusListener;
  final Map<String, String> _userNameCache = {};
  final Set<String> _userNameInFlight = <String>{};

  @override
  void initState() {
    super.initState();

    _socketConnected = apiClient.isSocketConnected;
    _socketStatusListener = (connected) {
      if (!mounted) return;
      setState(() => _socketConnected = connected);
    };
    apiClient.addSocketStatusListener(_socketStatusListener);

    _init();
  }

  @override
  void dispose() {
    apiClient.removeSocketStatusListener(_socketStatusListener);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final role = await apiClient.getPreferredRole();
      if (!mounted) return;
      setState(() => _role = role);
    } catch (_) {
      // ignore
    }

    await Future.wait([
      _loadThreads(showSpinner: true),
      _loadContacts(showSpinner: true),
    ]);
  }

  Future<void> _loadThreads({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }

    try {
      final threads = await apiClient.fetchThreads();
      if (!mounted) return;
      setState(() => _threads = threads);
      _primeNamesFromThreads(threads);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj dizileri alınamadı.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadContacts({bool showSpinner = false}) async {
    if (showSpinner && mounted) {
      setState(() => _contactsLoading = true);
    }

    try {
      final contacts = await apiClient.fetchContacts();
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kişi listesi alınamadı.')),
      );
    } finally {
      if (mounted) {
        setState(() => _contactsLoading = false);
      }
    }
  }

  void _primeNamesFromThreads(List<Map<String, dynamic>> threads) {
    final userIsCarrier = _role == 'carrier';
    for (final thread in threads) {
      final carrierId = thread['carrierId']?.toString() ?? '';
      final senderId = thread['senderId']?.toString() ?? '';
      final otherUserId = userIsCarrier ? senderId : carrierId;
      if (otherUserId.isEmpty) continue;
      _ensureUserName(otherUserId);
    }
  }

  Future<void> _ensureUserName(String userId) async {
    if (userId.isEmpty) return;
    if (_userNameCache.containsKey(userId)) return;
    if (_userNameInFlight.contains(userId)) return;

    _userNameInFlight.add(userId);
    try {
      final data = await apiClient.fetchUserById(userId);
      final nameAny = data['fullName'] ?? data['name'] ?? data['email'];
      final name = (nameAny?.toString() ?? '').trim();
      if (name.isNotEmpty) {
        _userNameCache[userId] = name;
      }
    } catch (_) {
      // ignore
    } finally {
      _userNameInFlight.remove(userId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _formatTime(dynamic createdAtRaw) {
    DateTime? created;
    if (createdAtRaw is DateTime) {
      created = createdAtRaw;
    } else {
      final raw = createdAtRaw?.toString();
      if (raw != null) {
        created = DateTime.tryParse(raw);
      }
    }

    if (created == null) return '';
    final local = created.isUtc ? created.toLocal() : created;
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final threadsCount = _threads.length;
    final contactsCount = _contacts.length;
    final hasContactsSection = contactsCount > 0;
    final contactsExtraRows = hasContactsSection ? (threadsCount > 0 ? 3 : 2) : 0;
    final itemCount = threadsCount + contactsExtraRows + contactsCount;

    final Widget content;
    if (_loading && _contactsLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_threads.isEmpty && _contacts.isEmpty) {
      content = ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Henüz görünür bir mesaj yok. Teklifleri bekle.'),
        ],
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index < threadsCount) {
            final thread = _threads[index];
            final time = _formatTime(thread['createdAt']);

            final listingId = thread['listingId']?.toString() ?? '';
            final carrierId = thread['carrierId']?.toString() ?? '';
            final senderId = thread['senderId']?.toString() ?? '';
            final userIsCarrier = _role == 'carrier';
            final otherUserId = userIsCarrier ? senderId : carrierId;
            final cachedName = _userNameCache[otherUserId];
            final displayName = cachedName ??
                (otherUserId.isNotEmpty
                    ? 'Kullanıcı ${otherUserId.substring(0, min(4, otherUserId.length))}'
                    : 'Kullanıcı');

            final title =
                '$displayName · Gönderi ${listingId.isEmpty ? '-' : listingId.substring(0, min(4, listingId.length))}';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                leading: CircleAvatar(
                  backgroundColor: BiTasiColors.primaryBlue.withAlpha(36),
                  child: const Icon(Icons.chat_bubble_outline, color: BiTasiColors.primaryBlue),
                ),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  thread['lastMessage']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
                onTap: () {
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
              ),
            );
          }

          if (!hasContactsSection) {
            return const SizedBox.shrink();
          }

          final contactsSectionStart = threadsCount;
          final contactsHeaderIndex = contactsSectionStart + 1;
          final contactsSpacerIndex = contactsSectionStart + 2;

          if (index == contactsSectionStart) {
            return const SizedBox(height: 16);
          }

          final headerText = _role == 'carrier' ? 'Göndericiler' : 'Carrierlar';
          if (index == contactsHeaderIndex) {
            return Text(headerText, style: const TextStyle(fontWeight: FontWeight.w700));
          }
          if (index == contactsSpacerIndex) {
            return const SizedBox(height: 12);
          }

          final contactIndex = index - threadsCount - contactsExtraRows;
          if (contactIndex < 0 || contactIndex >= contactsCount) {
            return const SizedBox.shrink();
          }

          final contact = _contacts[contactIndex];
          final isCarrier = _role == 'carrier';
          final contactTitle = isCarrier
              ? '${contact['activeListingsCount']?.toString() ?? '0'} aktif gönderi'
              : (contact['listingTitle']?.toString() ?? 'Yayındaki Gönderi');
          final name = isCarrier
              ? (contact['senderName']?.toString() ?? 'Gönderici')
              : (contact['carrierName']?.toString() ?? contact['carrierEmail']?.toString() ?? 'Carrier');
          final subtitle = isCarrier
              ? (contact['senderEmail']?.toString() ?? '')
              : (contact['carrierEmail']?.toString() ?? contactTitle);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            leading: CircleAvatar(
              backgroundColor:
                  isCarrier ? BiTasiColors.primaryBlue.withAlpha(36) : BiTasiColors.primaryRed.withAlpha(36),
              child: Icon(
                isCarrier ? Icons.person_outline : Icons.local_shipping,
                color: isCarrier ? BiTasiColors.primaryBlue : BiTasiColors.primaryRed,
              ),
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            onTap: () async {
              final userId = await apiClient.getCurrentUserId();
              if (!context.mounted) return;

              if (isCarrier) {
                try {
                  final senderListings = await apiClient.fetchListings();
                  if (!context.mounted) return;

                  final senderId = contact['senderId']?.toString() ?? '';
                  final relevantListings = senderListings
                      .where((listing) => listing['ownerId']?.toString() == senderId)
                      .toList();

                  if (relevantListings.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bu göndericinin aktif gönderisi bulunmuyor.')),
                    );
                    return;
                  }

                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('Gönderi Seçin'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: relevantListings.length,
                            itemBuilder: (context, index) {
                              final listing = relevantListings[index] as Map<String, dynamic>;
                              final listingTitle = listing['title']?.toString() ?? 'Gönderi ${index + 1}';
                              return ListTile(
                                title: Text(listingTitle),
                                subtitle: Text('ID: ${listing['id']}'),
                                onTap: () {
                                  Navigator.pop(dialogContext);
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
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('İptal'),
                          ),
                        ],
                      );
                    },
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gönderiler alınamadı.')),
                  );
                }
                return;
              }

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessageDetailScreen(
                    listingId: contact['listingId']?.toString() ?? '',
                    carrierId: contact['carrierId']?.toString() ?? '',
                    senderId: userId,
                    isCarrierUser: false,
                    listingTitle: contactTitle,
                  ),
                ),
              );
            },
          );
        },
      );
    }

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
          await Future.wait([
            _loadThreads(showSpinner: false),
            _loadContacts(showSpinner: false),
          ]);
        },
        child: content,
      ),
    );
  }
}


