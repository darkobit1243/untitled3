import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';

class TeklifListesiSheet extends StatelessWidget {
  const TeklifListesiSheet({super.key, required this.listingId, required this.title});

  final String listingId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6, // yarım ekran hissi
      child: FutureBuilder<List<dynamic>>(
        future: apiClient.fetchOffersForListing(listingId),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Teklifler - $title',
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
                Expanded(
                  child: ListView.separated(
                    itemCount: offers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final offer = offers[index] as Map<String, dynamic>;
                      final amount = offer['amount']?.toString() ?? '-';
                      final status = offer['status']?.toString() ?? 'pending';
                      final userLabel = offer['proposerId']?.toString() ?? 'Taşıyıcı';

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
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        shadowColor: Colors.black.withOpacity(0.05),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: TrustShipColors.primaryBlue.withOpacity(0.12),
                            child: const Icon(Icons.local_shipping, color: TrustShipColors.primaryBlue),
                          ),
                          title: Text(
                            '$amount TL',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kullanıcı: $userLabel', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
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
}