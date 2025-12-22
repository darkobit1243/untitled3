import 'package:flutter/material.dart';

import '../../theme/bitasi_theme.dart';

/// Widgets used by HomeScreen grouped in a single file to reduce clutter.

class PredictionList extends StatelessWidget {
  const PredictionList({super.key, required this.placePredictions, required this.onPlaceSelected});

  final List<dynamic> placePredictions;
  final void Function(String placeId, String description) onPlaceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: placePredictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = placePredictions[index] as Map<String, dynamic>;
          final description = item['description']?.toString() ?? '';
          return ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Colors.redAccent),
            title: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              final placeId = item['place_id']?.toString();
              if (placeId != null) {
                onPlaceSelected(placeId, description);
              }
            },
          );
        },
      ),
    );
  }
}

class NearbyListings extends StatelessWidget {
  const NearbyListings({
    super.key,
    required this.listings,
    required this.onOfferPressed,
    required this.onDetailsPressed,
    required this.onClose,
  });

  final List<Map<String, dynamic>> listings;
  final void Function(Map<String, dynamic> item) onOfferPressed;
  final void Function(Map<String, dynamic> item) onDetailsPressed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Text('Yakın İlanlar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = listings[index];
                final pickup = item['pickup_location']?['display']?.toString() ?? item['pickup_location']?['address']?.toString() ?? '?';
                final dropoff = item['dropoff_location']?['display']?.toString() ?? item['dropoff_location']?['address']?.toString() ?? '?';
                final distance = (item['__distance'] as double?)?.toStringAsFixed(1) ?? '?';
                final title = item['title']?.toString() ?? 'İlan';
                final price = item['price']?.toString() ?? 'Teklif yok';
                final weight = item['weight']?.toString() ?? '-';

                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Row(children: [const Icon(Icons.my_location, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      Row(children: [const Icon(Icons.place, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(dropoff, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const Spacer(),
                      Row(children: [_chip('$weight kg'), const SizedBox(width: 6), _chip('$distance km')]),
                      const SizedBox(height: 6),
                      Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        OutlinedButton.icon(
                          onPressed: () => onDetailsPressed(item),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                          label: const Text('Detay', style: TextStyle(color: Colors.black87, fontSize: 12)),
                        ),
                        ElevatedButton(
                          onPressed: () => onOfferPressed(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BiTasiColors.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: const Text('Teklif Ver'),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: BiTasiColors.backgroundGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
    );
  }
}

class RoleSummaryCard extends StatelessWidget {
  const RoleSummaryCard({
    super.key,
    required this.role,
    required this.isLoading,
    this.error,
    this.senderListingCount,
    this.senderPendingOffers,
    this.carrierDeliveryCount,
  });

  final String role;
  final bool isLoading;
  final String? error;
  final int? senderListingCount;
  final int? senderPendingOffers;
  final int? carrierDeliveryCount;

  @override
  Widget build(BuildContext context) {
    final isSender = role == 'sender';
    final title = isSender ? 'Gönderici Paneli' : 'Taşıyıcı Paneli';
    String subtitle;
    if (isLoading) {
      subtitle = 'Yükleniyor...';
    } else if (error != null) {
      subtitle = error!;
    } else if (isSender) {
      final offersTxt = senderPendingOffers != null ? ' • $senderPendingOffers bekleyen teklif' : '';
      subtitle = '${senderListingCount ?? 0} ilan$offersTxt';
    } else {
      subtitle = '${carrierDeliveryCount ?? 0} teslimat';
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const Spacer(),
            Icon(isSender ? Icons.local_shipping : Icons.route, color: Colors.black54, size: 20),
          ],
        ),
      ),
    );
  }
}

typedef ListingCallback = void Function(Map<String, dynamic> listing);

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.onOffersPressed,
    this.showOfferButton = true,
  });

  final Map<String, dynamic> listing;
  final ListingCallback? onOffersPressed;
  final bool showOfferButton;

  @override
  Widget build(BuildContext context) {
    final title = listing['title']?.toString() ?? 'Başlık yok';
    final pickup = listing['pickup_location']?['display']?.toString() ?? listing['pickup_location']?['address']?.toString() ?? '?';
    final dropoff = listing['dropoff_location']?['display']?.toString() ?? listing['dropoff_location']?['address']?.toString() ?? '?';
    final weight = listing['weight']?.toString() ?? '-';
    final listingId = listing['id']?.toString() ?? '';
    final statusRaw = listing['status']?.toString() ?? listing['deliveryStatus']?.toString() ?? listing['delivery_state']?.toString();

    String statusLabel = 'Teklif Bekliyor';
    Color statusColor = BiTasiColors.primaryRed;
    if (statusRaw != null) {
      switch (statusRaw) {
        case 'accepted':
        case 'pickup_pending':
          statusLabel = 'Kabul Edildi';
          statusColor = Colors.green;
          break;
        case 'in_transit':
          statusLabel = 'Yolda';
          statusColor = Colors.blue;
          break;
        case 'at_door':
          statusLabel = 'Kapıda';
          statusColor = BiTasiColors.warningOrange;
          break;
        case 'delivered':
          statusLabel = 'Teslim Edildi';
          statusColor = Colors.teal;
          break;
        case 'cancelled':
          statusLabel = 'İptal';
          statusColor = Colors.grey;
          break;
        case 'disputed':
          statusLabel = 'Uyuşmazlık';
          statusColor = BiTasiColors.errorRed;
          break;
        case 'rejected':
          statusLabel = 'Reddedildi';
          statusColor = Colors.grey;
          break;
        default:
          statusLabel = 'Teklif Bekliyor';
          statusColor = BiTasiColors.primaryRed;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(statusLabel, style: TextStyle(color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Pickup: $pickup', style: const TextStyle(color: Colors.grey)),
              Text('Drop: $dropoff', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
              Text('$weight kg', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: listingId.isEmpty
                        ? null
                        : () {
                            if (onOffersPressed != null) onOffersPressed!(listing);
                          },
                    child: const Text('Teklifleri Gör'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectedAddressChip extends StatelessWidget {
  const SelectedAddressChip({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          const Icon(Icons.place, color: BiTasiColors.primaryRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
