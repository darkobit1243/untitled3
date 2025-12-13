import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';

class IlanlarScreen extends StatefulWidget {
  const IlanlarScreen({super.key});

  @override
  State<IlanlarScreen> createState() => _IlanlarScreenState();
}

class _IlanlarScreenState extends State<IlanlarScreen> {
  bool _loading = true;
  List<dynamic> _listings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await apiClient.fetchListings();
      // Carrier kendi ilanına teklif veremesin diye filtrele
      final currentUserId = await apiClient.getCurrentUserId();
      final filtered = data.where((l) => l['ownerId']?.toString() != currentUserId).toList();
      if (!mounted) return;
      setState(() {
        _listings = filtered;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showOfferDialog(String listingId, String title) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Teklif ver: $title'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Teklif (TL)'),
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
                  await apiClient.createOffer(listingId: listingId, amount: value);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teklif gönderildi.')),
                  );
                  Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderici İlanları'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: _listings.isEmpty
                    ? const Center(child: Text('Gösterilecek ilan yok'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'Göndericilerden gelen ilanlar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _listings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _listings[index] as Map<String, dynamic>;
                                final title = item['title']?.toString() ?? 'İlan';
                                final pickup = item['pickup_location']?['address']?.toString() ?? 'Pickup';
                                final dropoff = item['dropoff_location']?['address']?.toString() ?? 'Dropoff';
                                final price = item['price']?.toString() ?? '—';
                                final weight = item['weight']?.toString() ?? '-';

                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  shadowColor: Colors.black.withOpacity(0.05),
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
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Text(
                                                '$weight kg',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.my_location, size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                pickup,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.grey),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.place, size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                dropoff,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.grey),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          price,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                // ileride detay modal
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                side: BorderSide(color: Colors.grey.shade300),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              icon: const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                                              label: const Text('Detay', style: TextStyle(color: Colors.black87, fontSize: 12)),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final currentUserId = await apiClient.getCurrentUserId();
                                                final listingOwnerId = item['ownerId']?.toString();
                                                if (currentUserId == listingOwnerId) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz.')),
                                                  );
                                                  return;
                                                }
                                                _showOfferDialog(item['id']?.toString() ?? '', title);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: TrustShipColors.primaryRed,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              ),
                                              child: const Text('Teklif Ver'),
                                            ),
                                          ],
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
              ),
      ),
    );
  }
}


