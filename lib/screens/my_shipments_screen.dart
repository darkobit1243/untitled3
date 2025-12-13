import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';

class MyShipmentsScreen extends StatefulWidget {
  const MyShipmentsScreen({super.key});

  @override
  State<MyShipmentsScreen> createState() => _MyShipmentsScreenState();
}

class _MyShipmentsScreenState extends State<MyShipmentsScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _activeListings = [];
  List<dynamic> _historyListings = [];

  // NOT: Teklif filtre/sıralama modaline ait fonksiyon, asıl sheet state'ine taşındı.

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
      // Fetch both listings and deliveries (accepted offers)
      final listingsData = await apiClient.fetchMyListings();
      final deliveriesData = await apiClient.fetchSenderDeliveries(); // accepted offers/deliveries for this sender

      final active = <dynamic>[];
      final history = <dynamic>[];

      // Add listings
      for (final listing in listingsData) {
        active.add({'type': 'listing', 'data': listing});
      }

      // Add accepted deliveries (these are accepted offers)
      for (final delivery in deliveriesData) {
        final status = delivery['status']?.toString() ?? '';
        if (status == 'in_transit' || status == 'pickup_pending') {
          active.add({'type': 'delivery', 'data': delivery});
        } else {
          history.add({'type': 'delivery', 'data': delivery});
        }
      }

      if (!mounted) return;
      setState(() {
        _activeListings = active;
        _historyListings = history;
      });
    } catch (e) {
      if (!mounted) return;
      // Debug: Show the actual error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler alınamadı: ${e.toString()}')),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gönderilerim'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aktif Gönderiler'),
              Tab(text: 'Geçmiş Gönderiler'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    _buildTaskList(_activeListings, true),
                    _buildTaskList(_historyListings, false),
                  ],
                ),
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

  Widget _buildTaskList(List<dynamic> items, bool isActive) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isActive ? 'Şu anda aktif gönderi yok.' : 'Geçmiş gönderi bulunamadı.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        final itemType = item['type'] as String?;
        final data = item['data'] as Map<String, dynamic>;

        if (itemType == 'delivery') {
          // Handle delivery items (accepted offers)
          final delivery = data;
          final listing = delivery['listing'] as Map<String, dynamic>? ?? {};
          final pickup = listing['pickup_location']?['address']?.toString() ?? '–';
          final dropoff = listing['dropoff_location']?['address']?.toString() ?? '–';
          final title = listing['title']?.toString() ?? 'İlan ${delivery['listingId'] ?? delivery['id'] ?? ''}';
          final status = delivery['status']?.toString() ?? 'unknown';
          final amount = listing['weight']?.toString() ?? '-';
          final chip = _buildStatusChip(status);

          final steps = [
            _TimelineStep('pickup_pending', 'Alım bekleniyor'),
            _TimelineStep('in_transit', 'Yolda'),
            _TimelineStep('delivered', 'Teslim edildi'),
          ];

          return Card(
            color: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      chip,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Kalkış: $pickup • Varış: $dropoff', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('Ağırlık: $amount kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildTimeline(status, steps),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (isActive)
                        ElevatedButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Konum güncelleme yakında eklenecek')),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TrustShipColors.primaryRed,
                          ),
                          child: const Text('Konumu Güncelle'),
                        ),
                      ElevatedButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gönderi detayları yakında eklenecek')),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TrustShipColors.backgroundGrey,
                        ),
                        child: const Text('Gönderi Detayı'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } else {
          // Handle listing items (regular listings)
          final listing = data;
          final pickup = listing['pickup_location']?['address']?.toString() ?? '–';
          final dropoff = listing['dropoff_location']?['address']?.toString() ?? '–';
          final title = listing['title']?.toString() ?? 'Gönderi ${listing['id'] ?? ''}';
          final status = 'active'; // For listings, consider them active
          final weight = listing['weight']?.toString() ?? '-';
          final chip = _buildStatusChip(status);

          return Card(
            color: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      chip,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Kalkış: $pickup • Varış: $dropoff', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('Ağırlık: $weight kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _openOffersForListing(listing['id']?.toString() ?? '', title),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TrustShipColors.primaryBlue,
                        ),
                        child: const Text('Teklifleri Gör'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = TrustShipColors.primaryBlue;
        label = 'Aktif';
        break;
      default:
        color = Colors.grey;
        label = 'Aktif';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTimeline(String status, List<_TimelineStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((step) {
        final isDone = _isStepDone(status, step.key);
        final isCurrent = status == step.key;
        final color = isDone ? TrustShipColors.successGreen : (isCurrent ? TrustShipColors.primaryBlue : Colors.grey);
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDone || isCurrent ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _isStepDone(String status, String key) {
    final order = ['pickup_pending', 'in_transit', 'delivered'];
    final currentIndex = order.indexOf(status);
    final stepIndex = order.indexOf(key);
    if (currentIndex == -1 || stepIndex == -1) return false;
    return currentIndex >= stepIndex;
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
  String _sort = 'amount_asc';
  String _statusFilter = 'all';

  List<dynamic> _applyFilters() {
    List<dynamic> list = List<dynamic>.from(_offers);
    if (_statusFilter != 'all') {
      list = list.where((o) => (o['status']?.toString() ?? '') == _statusFilter).toList();
    }
    list.sort((a, b) {
      final aa = (a['amount'] as num?)?.toDouble() ?? 0;
      final bb = (b['amount'] as num?)?.toDouble() ?? 0;
      final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      switch (_sort) {
        case 'amount_desc':
          return bb.compareTo(aa);
        case 'date_desc':
          return db.compareTo(da);
        case 'date_asc':
          return da.compareTo(db);
        case 'amount_asc':
        default:
          return aa.compareTo(bb);
      }
    });
    return list;
  }

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklifler alınamadı: ${e.toString()}')),
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
    final filtered = _applyFilters();

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
          if (!_loading && _offers.isNotEmpty)
            Row(
              children: [
                DropdownButton<String>(
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'amount_asc', child: Text('Artan fiyata göre')),
                    DropdownMenuItem(value: 'amount_desc', child: Text('Azalan fiyata göre')),
                    DropdownMenuItem(value: 'date_desc', child: Text('En yeni')),
                    DropdownMenuItem(value: 'date_asc', child: Text('En eski')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _sort = v);
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tümü')),
                    DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                    DropdownMenuItem(value: 'accepted', child: Text('Kabul')),
                    DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bu ilana henüz teklif gelmemiş.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final offer = filtered[index] as Map<String, dynamic>;
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

class _TimelineStep {
  final String key;
  final String label;
  const _TimelineStep(this.key, this.label);
}