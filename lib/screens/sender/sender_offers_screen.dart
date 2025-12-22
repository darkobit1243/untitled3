import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import 'teklif_listesi_sheet.dart';

class SenderOffersScreen extends StatefulWidget {
  const SenderOffersScreen({super.key});

  @override
  State<SenderOffersScreen> createState() => _SenderOffersScreenState();
}

class _SenderOffersScreenState extends State<SenderOffersScreen> {
  bool _loading = true;
  List<dynamic> _myListings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await apiClient.fetchMyListings();
      if (!mounted) return;
      setState(() => _myListings = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İlanlar alınamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openOffers(String listingId, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TeklifListesiSheet(listingId: listingId, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tekliflerim')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _myListings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _myListings[index] as Map<String, dynamic>;
                  final title = item['title']?.toString() ?? 'Başlık yok';
                  final desc = item['description']?.toString() ?? '';
                  final weight = item['weight']?.toString() ?? '-';
                  final listingId = item['id']?.toString() ?? '';
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping, color: BiTasiColors.primaryRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: BiTasiColors.backgroundGrey,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('$weight kg', style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: listingId.isEmpty ? null : () => _openOffers(listingId, title),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BiTasiColors.primaryRed,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Teklifleri Gör'),
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
}
