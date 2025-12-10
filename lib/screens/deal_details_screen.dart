import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';

/// Anlaşma detay ekranı:
/// - Paket özeti
/// - Teslimat durumu
/// - Teklif listesi ve (isteğe bağlı) teklif verme
class DealDetailsScreen extends StatefulWidget {
  const DealDetailsScreen({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<DealDetailsScreen> createState() => _DealDetailsScreenState();
}

class _DealDetailsScreenState extends State<DealDetailsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _delivery;
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
    final listingId = widget.listing['id']?.toString();
    try {
      if (listingId != null) {
        final results = await Future.wait([
          apiClient.fetchDeliveryForListing(listingId),
          apiClient.fetchOffersForListing(listingId),
        ]);
        _delivery = results[0] as Map<String, dynamic>?;
        _offers = results[1] as List<dynamic>;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detaylar alınamadı: $e')),
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
    final title = widget.listing['title'] as String? ?? 'Gönderi';
    final description = widget.listing['description'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Anlaşma Detayları',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              'İncele, teklifleri gör, durumu takip et',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPackageCard(title, description),
              const SizedBox(height: 16),
              _buildDeliveryCard(),
              const SizedBox(height: 16),
              _buildOffersSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard(String title, String description) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.inventory_2, color: TrustShipColors.primaryRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Paket Özeti',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: TrustShipColors.textDarkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: TrustShipColors.textDarkGrey,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryCard() {
    String statusLabel = 'Teslimat yok';
    Color statusColor = Colors.grey;
    String extra = 'Bu ilan için henüz bir teslimat oluşturulmadı.';

    if (_delivery != null) {
      final status = _delivery!['status']?.toString();
      final pickupAt = _delivery!['pickupAt']?.toString() ?? '';
      final deliveredAt = _delivery!['deliveredAt']?.toString() ?? '';

      if (status == 'pickup_pending') {
        statusLabel = 'Teslimat bekliyor';
        statusColor = TrustShipColors.warningOrange;
        extra = 'Kurye paketi henüz almadı.';
      } else if (status == 'in_transit') {
        statusLabel = 'Yolda';
        statusColor = TrustShipColors.primaryRed;
        extra = pickupAt.isNotEmpty ? 'Alım zamanı: $pickupAt' : 'Kurye yolda.';
      } else if (status == 'delivered') {
        statusLabel = 'Teslim edildi';
        statusColor = TrustShipColors.successGreen;
        extra = deliveredAt.isNotEmpty ? 'Teslim zamanı: $deliveredAt' : 'Teslimat tamamlandı.';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.route, color: TrustShipColors.successGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teslimat Durumu',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: TrustShipColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  extra,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    final listingId = widget.listing['id']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Teklifler',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: TrustShipColors.textDarkGrey,
                ),
              ),
              if (listingId != null)
                TextButton.icon(
                  onPressed: () => _showOfferDialog(listingId),
                  icon: const Icon(Icons.local_offer, size: 18),
                  label: const Text('Teklif ver'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_offers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Bu ilana henüz teklif gelmemiş.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final offer = _offers[index] as Map<String, dynamic>;
                final amount = offer['amount']?.toString() ?? '-';
                final status = offer['status']?.toString() ?? 'pending';

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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: TrustShipColors.backgroundGrey,
                      child: const Icon(Icons.person, color: TrustShipColors.primaryRed),
                    ),
                    title: Text(
                      '$amount TL',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Container(
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
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showOfferDialog(String listingId) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Teklif ver'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Teklif (TL)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () async {
                final value = double.tryParse(controller.text);
                if (value == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir tutar gir.')),
                  );
                  return;
                }

                try {
                  await apiClient.createOffer(
                    listingId: listingId,
                    amount: value,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teklif gönderildi.')),
                  );
                  Navigator.pop(context);
                  await _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Teklif gönderilemedi: $e')),
                  );
                }
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }
}
