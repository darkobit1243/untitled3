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
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teklif gönderildi.')),
                  );
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
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

  void _showDetailSheet(Map<String, dynamic> item) {
    final pickup = item['pickup_location']?['address']?.toString() ?? 'Pickup';
    final dropoff = item['dropoff_location']?['address']?.toString() ?? 'Dropoff';
    final price = item['price']?.toString() ?? '—';
    final weight = item['weight']?.toString() ?? '-';
    final distance = (item['__distance'] as num?)?.toStringAsFixed(1) ?? '–';
    final listingId = item['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['title']?.toString() ?? 'İlan',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.my_location, 'Kalkış', pickup),
            _infoRow(Icons.place, 'Varış', dropoff),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _chip('$weight kg'),
                _chip(distance == '–' ? 'Mesafe yok' : '$distance km'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Detaylar için gönderici ile mesajlaşabilirsiniz.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (item['ownerId'] != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openProfile(item['ownerId'].toString()),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profili Gör'),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: listingId.isEmpty ? null : () => _showOfferDialog(listingId, item['title']?.toString() ?? 'İlan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrustShipColors.primaryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Teklif Ver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProfile(String userId) async {
    try {
      final data = await apiClient.fetchUserById(userId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (data['avatarUrl'] as String?) != null ? NetworkImage(data['avatarUrl'] as String) : null,
                    child: (data['avatarUrl'] == null)
                        ? Text(
                            (data['fullName']?.toString().isNotEmpty ?? false)
                                ? data['fullName'].toString().characters.first.toUpperCase()
                                : 'U',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['fullName']?.toString() ?? data['email']?.toString() ?? 'Kullanıcı',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (data['rating'] != null)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              Text(data['rating'].toString(), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data['deliveredCount'] != null)
                Text('Tamamlanan teslimat: ${data['deliveredCount']}'),
              if (data['address'] != null)
                Text('Adres: ${data['address']}'),
              if (data['phone'] != null)
                Text('Telefon: ${data['phone']}'),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil alınamadı: $e')),
      );
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
      ),
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
                                final distance = (item['__distance'] as num?)?.toStringAsFixed(1) ?? '–';
                                final ownerName = item['ownerName']?.toString() ?? 'Gönderici';
                                final ownerAvatar = item['ownerAvatar']?.toString();
                                final rating = (item['ownerRating'] as num?)?.toDouble();
                                final delivered = (item['ownerDelivered'] as num?)?.toInt();
                                final ownerInitial = ownerName.isNotEmpty ? ownerName.characters.first.toUpperCase() : 'G';

                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  // ignore: deprecated_member_use
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
                                            const SizedBox(width: 8),
                                            _chip(distance == '–' ? 'Mesafe yok' : '$distance km'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Profil detayları yakında eklenecek')),
                                            );
                                          },
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: Colors.grey.shade200,
                                                backgroundImage: ownerAvatar != null ? NetworkImage(ownerAvatar) : null,
                                                child: ownerAvatar == null
                                                    ? Text(ownerInitial, style: const TextStyle(fontWeight: FontWeight.w700))
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      ownerName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                                    ),
                                                    Row(
                                                      children: [
                                                        if (rating != null) ...[
                                                          const Icon(Icons.star, size: 12, color: Colors.amber),
                                                          Text(
                                                            rating.toStringAsFixed(1),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                          ),
                                                        ],
                                                        if (delivered != null) ...[
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '$delivered teslimat',
                                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.person_outline, size: 18, color: Colors.black54),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
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
                                              onPressed: () => _showDetailSheet(item),
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
                                                  // ignore: use_build_context_synchronously
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


