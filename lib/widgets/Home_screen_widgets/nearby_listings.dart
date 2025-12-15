import 'package:flutter/material.dart';

import '../../theme/trustship_theme.dart';

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
                final pickup = item['pickup_location']?['address']?.toString() ?? '?';
                final dropoff = item['dropoff_location']?['address']?.toString() ?? '?';
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
                            backgroundColor: TrustShipColors.primaryRed,
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
      decoration: BoxDecoration(color: TrustShipColors.backgroundGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
    );
  }
}
