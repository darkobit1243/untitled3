import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/bitasi_theme.dart';

class TeklifListesiSheet extends StatefulWidget {
  const TeklifListesiSheet({
    super.key,
    required this.listingId,
    required this.title,
  });

  final String listingId;
  final String title;

  @override
  State<TeklifListesiSheet> createState() => _TeklifListesiSheetState();
}

class _TeklifListesiSheetState extends State<TeklifListesiSheet> {
  late Future<List<dynamic>> _future;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _future = apiClient.fetchOffersForListing(widget.listingId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = apiClient.fetchOffersForListing(widget.listingId);
    });
  }

  Future<void> _handleAccept(String offerId) async {
    setState(() => _actionLoading = true);
    try {
      await apiClient.acceptOffer(offerId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teklif kabul edildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kabul edilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _handleReject(String offerId) async {
    setState(() => _actionLoading = true);
    try {
      await apiClient.rejectOffer(offerId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teklif reddedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reddedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.65, // biraz daha ferah yarım ekran
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Teklifler alınamadı: ${snapshot.error}'),
            );
          }

          final offers = snapshot.data ?? [];
          if (offers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Bu ilana henüz teklif gelmemiş.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Teklifler - ${widget.title}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${offers.length} teklif',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_actionLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (_actionLoading) const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: offers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final offer = offers[index] as Map<String, dynamic>;
                      final amount = offer['amount']?.toString() ?? '-';
                      final status = offer['status']?.toString() ?? 'pending';
                      final userLabel = offer['proposerName']?.toString() ?? offer['proposerId']?.toString() ?? 'Taşıyıcı';
                      final avatar = offer['proposerAvatar']?.toString();
                      final rating = (offer['proposerRating'] as num?)?.toDouble();
                      final delivered = (offer['proposerDelivered'] as num?)?.toInt();
                      final proposerId = offer['proposerId']?.toString();
                      final createdAt = offer['createdAt']?.toString() ?? '';
                      final offerId = offer['id']?.toString() ?? '';

                      Color statusColor;
                      String statusText;
                      switch (status) {
                        case 'accepted':
                          statusColor = BiTasiColors.successGreen;
                          statusText = 'Kabul edildi';
                          break;
                        case 'rejected':
                          statusColor = BiTasiColors.errorRed;
                          statusText = 'Reddedildi';
                          break;
                        default:
                          statusColor = BiTasiColors.warningOrange;
                          statusText = 'Bekliyor';
                      }

                      final isPending = status == 'pending';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: BiTasiColors.primaryBlue.withAlpha(31),
                                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                    child: avatar == null
                                        ? const Icon(Icons.local_shipping, color: BiTasiColors.primaryBlue)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$amount TL',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Kullanıcı: $userLabel', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(31),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (rating != null) ...[
                                    const Icon(Icons.star, size: 12, color: Colors.amber),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  if (delivered != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '$delivered teslimat',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (proposerId != null)
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          final data = await apiClient.fetchUserById(proposerId);
                                          if (context.mounted) {
                                            _showProfileSheet(context, data);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Profil alınamadı: $e')),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Profili Gör'),
                                    ),
                                ],
                              ),
                              if (createdAt.isNotEmpty)
                                Text(
                                  createdAt,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              if (isPending) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _actionLoading ? null : () => _handleReject(offerId),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: BiTasiColors.errorRed,
                                          side: const BorderSide(color: BiTasiColors.errorRed),
                                        ),
                                        child: const Text('Reddet'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _actionLoading ? null : () => _handleAccept(offerId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: BiTasiColors.successGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Kabul Et'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProfileSheet(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (data['avatarUrl'] as String?) != null ? NetworkImage(data['avatarUrl'] as String) : null,
                  child: data['avatarUrl'] == null
                      ? Text(
                          (data['fullName']?.toString().isNotEmpty ?? false)
                              ? data['fullName'].toString().characters.first.toUpperCase()
                              : 'U',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName']?.toString() ?? data['email']?.toString() ?? 'Kullanıcı',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          if (data['rating'] != null) ...[
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(data['rating'].toString(), style: const TextStyle(fontSize: 12)),
                          ],
                          if (data['deliveredCount'] != null) ...[
                            const SizedBox(width: 6),
                            Text('${data['deliveredCount']} teslimat', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data['address'] != null) Text('Adres: ${data['address']}'),
            if (data['phone'] != null) Text('Telefon: ${data['phone']}'),
          ],
        ),
      ),
    );
  }
}