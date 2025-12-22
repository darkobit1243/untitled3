import 'package:flutter/material.dart';

import '../models/delivery_status.dart';
import '../services/api_client.dart';
import 'live_tracking_screen.dart';
import 'offer_amount_screen.dart';
import '../theme/bitasi_theme.dart';

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
            color: Colors.black.withAlpha(13),
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
              Icon(Icons.inventory_2, color: BiTasiColors.primaryRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Paket Özeti',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: BiTasiColors.textDarkGrey,
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
              color: BiTasiColors.textDarkGrey,
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

    final deliveryId = _delivery?['id']?.toString() ?? '';
    final trackingEnabled = _delivery?['trackingEnabled'] == true;

    if (_delivery != null) {
      final status = _delivery!['status']?.toString().toLowerCase();
      final pickupAt = _delivery!['pickupAt']?.toString() ?? '';
      final deliveredAt = _delivery!['deliveredAt']?.toString() ?? '';

      if (status == DeliveryStatus.pickupPending) {
        statusLabel = 'Teslimat bekliyor';
        statusColor = BiTasiColors.warningOrange;
        extra = 'Kurye paketi henüz almadı.';
      } else if (status == DeliveryStatus.inTransit) {
        statusLabel = 'Yolda';
        statusColor = BiTasiColors.primaryRed;
        extra = pickupAt.isNotEmpty ? 'Alım zamanı: $pickupAt' : 'Kurye yolda.';
      } else if (status == DeliveryStatus.delivered) {
        statusLabel = 'Teslim edildi';
        statusColor = BiTasiColors.successGreen;
        extra = deliveredAt.isNotEmpty ? 'Teslim zamanı: $deliveredAt' : 'Teslimat tamamlandı.';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: BiTasiColors.successGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teslimat Durumu',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BiTasiColors.textDarkGrey,
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
                  color: statusColor.withAlpha(26),
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
          if (trackingEnabled && deliveryId.isNotEmpty) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LiveTrackingScreen(deliveryId: deliveryId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
              child: const Text('Canlı Takip'),
            ),
          ],
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
            color: Colors.black.withAlpha(13),
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
                  color: BiTasiColors.textDarkGrey,
                ),
              ),
              if (listingId != null)
                TextButton.icon(
                  onPressed: () async => _showOfferDialog(listingId),
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

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: BiTasiColors.backgroundGrey,
                      child: const Icon(Icons.person, color: BiTasiColors.primaryRed),
                    ),
                    title: Text(
                      '$amount TL',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(26),
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

  Future<void> _showOfferDialog(String listingId) async {
    final title = widget.listing['title']?.toString() ?? 'İlan';

    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        pageBuilder: (_, __, ___) => OfferAmountScreen(title: title),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted) return;
    if (result == null || result.trim().isEmpty) return;

    final normalized = result.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin.')),
      );
      return;
    }

    try {
      await apiClient.createOffer(listingId: listingId, amount: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif gönderildi.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('zaten kabul edilmiş')
          ? 'Bu ilan için teklif kabul edilmiş. Artık teklif verilemez.'
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklif gönderilemedi: $msg')),
      );
      await _load();
    }
  }
}
