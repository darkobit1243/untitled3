import 'package:flutter/material.dart';

import '../theme/trustship_theme.dart';

/// Basit anlaşma detay ekranı iskeleti.
/// Şimdilik sadece listing bilgisini gösteriyor ve ileride
/// offers/deliveries endpoint'leri ile zenginleştirilebilir.
class DealDetailsScreen extends StatelessWidget {
  const DealDetailsScreen({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final title = listing['title'] as String? ?? 'Gönderi';
    final description = listing['description'] as String? ?? '';

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
              'İncele & pazarlık yap',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Paket özet kartı
            Container(
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
            ),
            const SizedBox(height: 16),

            // Geçici bilgi metni
            const Text(
              'Bu ekran, kargo-backend ile teklif ve teslimat akışını '
              'yöneteceğiniz DealDetails ekranının iskeletidir. '
              'Bir sonraki adımda chat, teklif ve emanet ödeme bölümleri eklenecek.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}


