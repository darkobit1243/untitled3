import 'package:flutter/material.dart';
import '../../theme/trustship_theme.dart';

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
    final pickup = listing['pickup_location']?['address']?.toString() ?? '?';
    final dropoff = listing['dropoff_location']?['address']?.toString() ?? '?';
    final weight = listing['weight']?.toString() ?? '-';
    final listingId = listing['id']?.toString() ?? '';
    final statusRaw = listing['status']?.toString() ?? listing['deliveryStatus']?.toString() ?? listing['delivery_state']?.toString();

    String statusLabel = 'Teklif Bekliyor';
    Color statusColor = TrustShipColors.primaryRed;
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
        case 'delivered':
          statusLabel = 'Teslim Edildi';
          statusColor = Colors.teal;
          break;
        case 'rejected':
          statusLabel = 'Reddedildi';
          statusColor = Colors.grey;
          break;
        default:
          statusLabel = 'Teklif Bekliyor';
          statusColor = TrustShipColors.primaryRed;
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
