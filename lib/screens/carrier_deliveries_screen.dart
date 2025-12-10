import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';

class CarrierDeliveriesScreen extends StatefulWidget {
  const CarrierDeliveriesScreen({super.key});

  @override
  State<CarrierDeliveriesScreen> createState() => _CarrierDeliveriesScreenState();
}

class _CarrierDeliveriesScreenState extends State<CarrierDeliveriesScreen> {
  bool _loading = true;
  List<dynamic> _items = [];

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
      final data = await apiClient.fetchCarrierDeliveries();
      setState(() {
        _items = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teslimatlar alınamadı: $e')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Teslimatlarım')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Henüz sana atanmış teslimat yok.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index] as Map<String, dynamic>;
                      final id = item['id']?.toString() ?? '';
                      final listingId = item['listingId']?.toString() ?? '';
                      final status = item['status']?.toString() ?? '';
                      final pickupAt = item['pickupAt']?.toString() ?? '';
                      final deliveredAt = item['deliveredAt']?.toString() ?? '';

                      String statusLabel;
                      Color statusColor;
                      if (status == 'pickup_pending') {
                        statusLabel = 'Alım bekleniyor';
                        statusColor = TrustShipColors.warningOrange;
                      } else if (status == 'in_transit') {
                        statusLabel = 'Yolda';
                        statusColor = TrustShipColors.primaryRed;
                      } else if (status == 'delivered') {
                        statusLabel = 'Teslim edildi';
                        statusColor = TrustShipColors.successGreen;
                      } else {
                        statusLabel = 'Bilinmiyor';
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
                            'Listing: $listingId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pickupAt.isNotEmpty)
                                Text(
                                  'Alındı: $pickupAt',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              if (deliveredAt.isNotEmpty)
                                Text(
                                  'Teslim: $deliveredAt',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
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
                              const SizedBox(height: 6),
                              if (status == 'pickup_pending')
                                TextButton(
                                  onPressed: () => _updateStatus(id, true),
                                  child: const Text(
                                    'Teslimatı Al',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                )
                              else if (status == 'in_transit')
                                TextButton(
                                  onPressed: () => _updateStatus(id, false),
                                  child: const Text(
                                    'Teslim Et',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _updateStatus(String deliveryId, bool pickup) async {
    try {
      if (pickup) {
        await apiClient.pickupDelivery(deliveryId);
      } else {
        await apiClient.deliverDelivery(deliveryId);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pickup ? 'Teslimat alındı.' : 'Teslim edildi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }
}
