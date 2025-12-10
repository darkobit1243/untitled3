import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';

class MyShipmentsScreen extends StatefulWidget {
  const MyShipmentsScreen({super.key});

  @override
  State<MyShipmentsScreen> createState() => _MyShipmentsScreenState();
}

class _MyShipmentsScreenState extends State<MyShipmentsScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  final Map<String, Map<String, dynamic>?> _deliveryByListing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await apiClient.fetchMyListings();
      setState(() {
        _items = data;
      });

      // Her ilan için teslimat durumunu yükle
      for (final raw in data) {
        final item = raw as Map<String, dynamic>;
        final id = item['id']?.toString();
        if (id == null) continue;
        try {
          final delivery = await apiClient.fetchDeliveryForListing(id);
          _deliveryByListing[id] = delivery;
        } catch (_) {
          _deliveryByListing[id] = null;
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kargoların alınamadı, bağlantını kontrol et.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kargolarım')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Henüz hiç ilan oluşturmamışsın.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index] as Map<String, dynamic>;
                      final title = item['title']?.toString() ?? 'Başlık yok';
                      final desc = item['description']?.toString() ?? '';
                      final createdAt = item['createdAt']?.toString() ?? '';
                      final listingId = item['id']?.toString() ?? '';
                      final delivery = _deliveryByListing[listingId];
                      final status = delivery?['status']?.toString();

                      String statusLabel;
                      Color statusColor;
                      if (status == 'pickup_pending') {
                        statusLabel = 'Teslimat bekliyor';
                        statusColor = TrustShipColors.warningOrange;
                      } else if (status == 'in_transit') {
                        statusLabel = 'Yolda';
                        statusColor = TrustShipColors.primaryRed;
                      } else if (status == 'delivered') {
                        statusLabel = 'Teslim edildi';
                        statusColor = TrustShipColors.successGreen;
                      } else {
                        statusLabel = 'Teslimat yok';
                        statusColor = Colors.grey;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: TrustShipColors.backgroundGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_shipping, color: TrustShipColors.primaryRed),
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (desc.isNotEmpty)
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                createdAt,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: listingId.isEmpty
                              ? null
                              : () => _openOffersForListing(listingId, title),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _openOffersForListing(String listingId, String title) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _OffersForListingSheet(listingId: listingId, title: title);
      },
    );
  }
}

class _OffersForListingSheet extends StatefulWidget {
  const _OffersForListingSheet({
    required this.listingId,
    required this.title,
  });

  final String listingId;
  final String title;

  @override
  State<_OffersForListingSheet> createState() => _OffersForListingSheetState();
}

class _OffersForListingSheetState extends State<_OffersForListingSheet> {
  bool _loading = true;
  List<dynamic> _offers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await apiClient.fetchOffersForListing(widget.listingId);
      setState(() {
        _offers = data;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklifler alınamadı, bağlantını kontrol et.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Teklifler - ${widget.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_offers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bu ilana henüz teklif gelmemiş.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final offer = _offers[index] as Map<String, dynamic>;
                  final amount = offer['amount']?.toString() ?? '-';
                  final status = offer['status']?.toString() ?? 'pending';
                  final id = offer['id']?.toString() ?? '';

                  Color statusColor;
                  String statusText;
                  switch (status) {
                    case 'accepted':
                      statusColor = TrustShipColors.successGreen;
                      statusText = 'Kabul edildi';
                      break;
                    case 'rejected':
                      statusColor = TrustShipColors.errorRed;
                      statusText = 'Reddedildi';
                      break;
                    default:
                      statusColor = TrustShipColors.warningOrange;
                      statusText = 'Bekliyor';
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        '$amount TL',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: status == 'pending'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: TrustShipColors.errorRed),
                                  onPressed: () => _updateOffer(id, false),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: TrustShipColors.successGreen),
                                  onPressed: () => _updateOffer(id, true),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateOffer(String offerId, bool accept) async {
    try {
      if (accept) {
        await apiClient.acceptOffer(offerId);
      } else {
        await apiClient.rejectOffer(offerId);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Teklif kabul edildi.' : 'Teklif reddedildi.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem başarısız, tekrar dene.')),
      );
    }
  }
}