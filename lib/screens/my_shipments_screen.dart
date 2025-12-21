import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../services/google_places_service.dart';
import '../services/location_label_cache.dart';
import '../models/delivery_status.dart';
import 'live_tracking_screen.dart';
import '../theme/bitasi_theme.dart';

class MyShipmentsScreen extends StatefulWidget {
  const MyShipmentsScreen({super.key, this.initialOpenOffersListingId});

  final String? initialOpenOffersListingId;

  @override
  State<MyShipmentsScreen> createState() => _MyShipmentsScreenState();
}

class _MyShipmentsScreenState extends State<MyShipmentsScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _activeListings = [];
  List<dynamic> _historyListings = [];

  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  final Map<String, String> _locationLabelCache = <String, String>{};
  final Set<String> _locationLabelInFlight = <String>{};

  final Set<String> _ratedDeliveryIds = <String>{};

  final Set<String> _offerBadgeListingIds = <String>{};
  final Set<String> _offerSubscribedListingIds = <String>{};

  // NOT: Teklif filtre/sıralama modaline ait fonksiyon, asıl sheet state'ine taşındı.

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final id in _offerSubscribedListingIds) {
      apiClient.stopFollowingOfferUpdates(id);
    }
    _offerSubscribedListingIds.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Fetch listings + deliveries + my ratings concurrently for faster loading.
      final results = await Future.wait<dynamic>([
        apiClient.fetchMyListings(),
        apiClient.fetchSenderDeliveries(),
        apiClient.fetchMyGivenRatings().catchError((_) => <dynamic>[]),
      ]);

      final listingsData = results[0] is List ? List<dynamic>.from(results[0] as List) : <dynamic>[];
      final deliveriesData = results[1] is List ? List<dynamic>.from(results[1] as List) : <dynamic>[];
      final mineRatings = results[2] is List ? List<dynamic>.from(results[2] as List) : <dynamic>[];

      // Only hide listings from the active list if the related delivery is delivered.
      // For pickup pending / in transit we keep the listing in active, as requested.
      final deliveredListingIds = <String>{};
      for (final d in deliveriesData) {
        if (d is! Map) continue;
        final status = d['status']?.toString().toLowerCase() ?? '';
        if (status != DeliveryStatus.delivered) continue;

        final listingId = d['listingId']?.toString() ?? (d['listing'] is Map ? (d['listing'] as Map)['id']?.toString() : null);
        if (listingId != null && listingId.isNotEmpty) {
          deliveredListingIds.add(listingId);
        }
      }

      final active = <dynamic>[];
      final history = <dynamic>[];

      // Add listings
      for (final listing in listingsData) {
        if (listing is Map) {
          final listingId = listing['id']?.toString() ?? '';
          if (listingId.isNotEmpty && deliveredListingIds.contains(listingId)) {
            // Delivered shipments should not appear under active listings.
            continue;
          }
        }
        active.add({'type': 'listing', 'data': listing});
      }

      _syncOfferSubscriptions(listingsData);

      // Add accepted deliveries (these are accepted offers)
      for (final delivery in deliveriesData) {
        if (delivery is! Map) {
          history.add({'type': 'delivery', 'data': delivery});
          continue;
        }
        final status = delivery['status']?.toString().toLowerCase() ?? '';
        if (status == DeliveryStatus.inTransit || status == DeliveryStatus.pickupPending) {
          active.add({'type': 'delivery', 'data': delivery});
        } else {
          history.add({'type': 'delivery', 'data': delivery});
        }
      }

      // Fetch current user's given ratings once; used to hide "Puan Ver".
      final ratedIds = <String>{};
      for (final r in mineRatings) {
        if (r is Map) {
          final deliveryId = r['deliveryId']?.toString() ?? '';
          if (deliveryId.isNotEmpty) ratedIds.add(deliveryId);
        }
      }

      if (!mounted) return;
      setState(() {
        _activeListings = active;
        _historyListings = history;
        _ratedDeliveryIds
          ..clear()
          ..addAll(ratedIds);
      });

      // Fill pickup/dropoff labels in the background.
      // ignore: unawaited_futures
      _hydrateAddressLabels();

      _maybeAutoOpenOffers();
    } catch (e) {
      if (!mounted) return;
      // Debug: Show the actual error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler alınamadı: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> _hydrateAddressLabels() async {
    final items = <dynamic>[..._activeListings, ..._historyListings];

    // Sequential requests to avoid hammering Geocoding API.
    var anyUpdates = false;
    var updatesSinceLastSetState = 0;
    for (final entry in items) {
      if (!mounted) return;
      if (entry is! Map) continue;
      final type = entry['type']?.toString();
      final data = entry['data'];
      final dataMap = _asStringMap(data);
      if (dataMap == null) continue;

      Map<String, dynamic>? listing;
      if (type == 'listing') {
        listing = dataMap;
      } else if (type == 'delivery') {
        listing = _asStringMap(dataMap['listing']);
      }
      if (listing == null) continue;

      final listingId = listing['id']?.toString() ?? dataMap['listingId']?.toString();
      final pickupUpdated = await _ensureLocationLabel(
        listingId: listingId,
        listing: listing,
        locationKey: 'pickup_location',
      );
      final dropoffUpdated = await _ensureLocationLabel(
        listingId: listingId,
        listing: listing,
        locationKey: 'dropoff_location',
      );

      if (!mounted) return;
      final updatedCount = (pickupUpdated ? 1 : 0) + (dropoffUpdated ? 1 : 0);
      if (updatedCount > 0) {
        anyUpdates = true;
        updatesSinceLastSetState += updatedCount;
        // Batch redraws to avoid jank while still letting labels appear progressively.
        if (updatesSinceLastSetState >= 6) {
          setState(() {});
          updatesSinceLastSetState = 0;
        }
      }
    }

    if (!mounted) return;
    if (anyUpdates && updatesSinceLastSetState > 0) {
      setState(() {});
    }
  }

  Future<bool> _ensureLocationLabel({
    required String? listingId,
    required Map<String, dynamic> listing,
    required String locationKey,
  }) async {
    final loc = _asStringMap(listing[locationKey]);
    if (loc == null) return false;

    final existing = (loc['display'] ?? loc['address'])?.toString() ?? '';
    if (existing.trim().isNotEmpty) return false;

    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return false;

    final persisted = await LocationLabelCache.getLabel(lat: lat, lng: lng);
    if (persisted != null && persisted.trim().isNotEmpty) {
      loc['display'] = persisted;
      loc['address'] = persisted;
      listing[locationKey] = loc;
      return true;
    }

    final key = '${listingId ?? ''}|$locationKey|${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    final cached = _locationLabelCache[key];
    if (cached != null && cached.trim().isNotEmpty) {
      loc['display'] = cached;
      loc['address'] = cached;
      listing[locationKey] = loc;
      return true;
    }

    if (_locationLabelInFlight.contains(key)) return false;
    _locationLabelInFlight.add(key);
    try {
      final parts = await _places.reverseGeocodeParts(position: LatLng(lat, lng));
      final label = parts?.toDisplayString();
      if (!mounted) return false;
      if (label == null || label.trim().isEmpty) return false;

      // Persist across restarts.
      // ignore: unawaited_futures
      LocationLabelCache.setLabel(lat: lat, lng: lng, label: label);

      _locationLabelCache[key] = label;
      loc['display'] = label;
      loc['address'] = label;
      listing[locationKey] = loc;

      return true;
    } catch (_) {
      // ignore
    } finally {
      _locationLabelInFlight.remove(key);
    }

    return false;
  }

  void _maybeAutoOpenOffers() {
    final targetId = widget.initialOpenOffersListingId;
    if (targetId == null || targetId.isEmpty) return;

    // Only try once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final all = <dynamic>[..._activeListings, ..._historyListings];
      String? title;
      for (final item in all) {
        if (item is! Map<String, dynamic>) continue;
        if (item['type'] != 'listing') continue;
        final data = item['data'] as Map<String, dynamic>;
        final id = data['id']?.toString();
        if (id == targetId) {
          title = data['title']?.toString() ?? 'Gönderi';
          break;
        }
      }
      _openOffersForListing(targetId, title ?? 'Gönderi');
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gönderilerim'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aktif Gönderiler'),
              Tab(text: 'Geçmiş Gönderiler'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    _buildTaskList(_activeListings, true),
                    _buildTaskList(_historyListings, false),
                  ],
                ),
        ),
      ),
    );
  }

  void _openOffersForListing(String listingId, String title) async {
    if (_offerBadgeListingIds.remove(listingId)) {
      if (mounted) setState(() {});
    }
    final transitionController = AnimationController(
      vsync: this,
      duration: Duration.zero,
      reverseDuration: Duration.zero,
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        transitionAnimationController: transitionController,
        builder: (context) {
          return _OffersForListingSheet(listingId: listingId, title: title);
        },
      );
    } finally {
      transitionController.dispose();
    }
  }

  void _syncOfferSubscriptions(List<dynamic> listingsData) {
    final listingIds = listingsData
        .map((e) => (e as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final toRemove = _offerSubscribedListingIds.difference(listingIds);
    for (final id in toRemove) {
      apiClient.stopFollowingOfferUpdates(id);
      _offerSubscribedListingIds.remove(id);
      _offerBadgeListingIds.remove(id);
    }

    final toAdd = listingIds.difference(_offerSubscribedListingIds);
    for (final id in toAdd) {
      _offerSubscribedListingIds.add(id);
      apiClient.followOfferUpdates(id, (data) => _onOfferEvent(id, data));
    }
  }

  Future<void> _onOfferEvent(String listingId, dynamic data) async {
    if (!mounted) return;
    setState(() {
      _offerBadgeListingIds.add(listingId);
    });

    final enabled = await appSettings.getNotificationsEnabled();
    if (!mounted || !enabled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yeni teklif geldi.')),
    );
  }

  Future<void> _showRatingDialog({required String deliveryId, required String title}) async {
    final commentController = TextEditingController();
    int score = 5;
    bool submitting = false;
    String? error;

    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (submitting) return;
              setDialogState(() {
                submitting = true;
                error = null;
              });
              try {
                await apiClient.createRating(
                  deliveryId: deliveryId,
                  score: score,
                  comment: commentController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('Puanın kaydedildi.')));
                await _load();
              } catch (e) {
                setDialogState(() {
                  error = e.toString();
                });
              } finally {
                setDialogState(() {
                  submitting = false;
                });
              }
            }

            Widget star(int i) {
              final selected = i <= score;
              return IconButton(
                onPressed: submitting
                    ? null
                    : () {
                        setDialogState(() {
                          score = i;
                        });
                      },
                icon: Icon(
                  selected ? Icons.star : Icons.star_border,
                  color: BiTasiColors.warningOrange,
                ),
              );
            }

            return AlertDialog(
              title: Text('Puan Ver: $title'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Taşıyıcıyı değerlendir', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [star(1), star(2), star(3), star(4), star(5)],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      enabled: !submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Yorum (opsiyonel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  Widget _buildTaskList(List<dynamic> items, bool isActive) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isActive ? 'Şu anda aktif gönderi yok.' : 'Geçmiş gönderi bulunamadı.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        final itemType = item['type'] as String?;
        final data = item['data'] as Map<String, dynamic>;

        if (itemType == 'delivery') {
          // Handle delivery items (accepted offers)
          final delivery = data;
          final listing = delivery['listing'] as Map<String, dynamic>? ?? {};
          final deliveryId = delivery['id']?.toString() ?? '';
          final pickupQrToken = delivery['pickupQrToken']?.toString() ?? '';
          final pickup = listing['pickup_location']?['address']?.toString() ?? '–';
          final dropoff = listing['dropoff_location']?['address']?.toString() ?? '–';
          final title = listing['title']?.toString() ?? 'İlan ${delivery['listingId'] ?? delivery['id'] ?? ''}';
          final status = delivery['status']?.toString().toLowerCase() ?? 'unknown';
          final trackingEnabled = delivery['trackingEnabled'] == true;
          final amount = listing['weight']?.toString() ?? '-';
          final chip = _buildStatusChip(status);

          final steps = [
            _TimelineStep(DeliveryStatus.pickupPending, 'Alım bekleniyor'),
            _TimelineStep(DeliveryStatus.inTransit, 'Yolda'),
            _TimelineStep(DeliveryStatus.delivered, 'Teslim edildi'),
          ];

          return Card(
            color: Colors.white.withAlpha(242),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      chip,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Kalkış: $pickup • Varış: $dropoff', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('Ağırlık: $amount kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildTimeline(status, steps),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (status == DeliveryStatus.pickupPending && pickupQrToken.isNotEmpty)
                        ElevatedButton(
                          onPressed: () => _showPickupQr(context, pickupQrToken),
                          style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryBlue),
                          child: const Text('QR Göster'),
                        ),
                      if ((trackingEnabled || status == DeliveryStatus.inTransit) && deliveryId.isNotEmpty)
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
                      if (status == DeliveryStatus.delivered && deliveryId.isNotEmpty)
                        ElevatedButton(
                          onPressed: _ratedDeliveryIds.contains(deliveryId)
                              ? null
                              : () => _showRatingDialog(deliveryId: deliveryId, title: title),
                          style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.successGreen),
                          child: Text(_ratedDeliveryIds.contains(deliveryId) ? 'Puanlandı' : 'Puan Ver'),
                        ),
                      ElevatedButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gönderi detayları yakında eklenecek')),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BiTasiColors.backgroundGrey,
                        ),
                        child: const Text('Gönderi Detayı'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } else {
          // Handle listing items (regular listings)
          final listing = data;
          final listingId = listing['id']?.toString() ?? '';
          final hasOfferBadge = listingId.isNotEmpty && _offerBadgeListingIds.contains(listingId);
          final pickup = listing['pickup_location']?['address']?.toString() ?? '–';
          final dropoff = listing['dropoff_location']?['address']?.toString() ?? '–';
          final title = listing['title']?.toString() ?? 'Gönderi ${listing['id'] ?? ''}';
          final status = 'active'; // For listings, consider them active
          final weight = listing['weight']?.toString() ?? '-';
          final chip = _buildStatusChip(status);

          return Card(
            color: Colors.white.withAlpha(242),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      if (hasOfferBadge)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: BiTasiColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      chip,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Kalkış: $pickup • Varış: $dropoff', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('Ağırlık: $weight kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _openOffersForListing(listingId, title),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BiTasiColors.primaryBlue,
                        ),
                        child: const Text('Teklifleri Gör'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  void _showPickupQr(BuildContext context, String token) {
    showDialog<void>(
      context: context,
      builder: (_) {
        // NOTE: AlertDialog uses IntrinsicWidth/IntrinsicHeight which can trigger
        // intrinsic measurement on children. qr_flutter internally uses LayoutBuilder,
        // which throws during intrinsic sizing. A sized Dialog avoids that path.
        final painter = QrPainter(
          data: token,
          version: QrVersions.auto,
          gapless: true,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        );

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Teslimat QR Kodu',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: painter,
                      size: const Size.square(200),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kurye teslimatı almak için bu QR kodu okutmalıdır.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kapat'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = BiTasiColors.primaryBlue;
        label = 'Aktif';
        break;
      default:
        color = Colors.grey;
        label = 'Aktif';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTimeline(String status, List<_TimelineStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((step) {
        final isDone = _isStepDone(status, step.key);
        final isCurrent = status == step.key;
        final color = isDone ? BiTasiColors.successGreen : (isCurrent ? BiTasiColors.primaryBlue : Colors.grey);
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDone || isCurrent ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _isStepDone(String status, String key) {
    final order = [
      DeliveryStatus.pickupPending,
      DeliveryStatus.inTransit,
      DeliveryStatus.delivered,
    ];
    final currentIndex = order.indexOf(status);
    final stepIndex = order.indexOf(key);
    if (currentIndex == -1 || stepIndex == -1) return false;
    return currentIndex >= stepIndex;
  }
}

class _OffersForListingSheet extends StatefulWidget {
  const _OffersForListingSheet({
    required this.listingId,
    required this.title,
  });

  final String listingId;
  final String title;

  @override
  State<_OffersForListingSheet> createState() => _OffersForListingSheetState();
}

class _OffersForListingSheetState extends State<_OffersForListingSheet> {
  bool _loading = true;
  List<dynamic> _offers = [];
  String _sort = 'amount_asc';
  String _statusFilter = 'all';

  List<dynamic> _applyFilters() {
    List<dynamic> list = List<dynamic>.from(_offers);
    if (_statusFilter != 'all') {
      list = list.where((o) => (o['status']?.toString() ?? '') == _statusFilter).toList();
    }
    list.sort((a, b) {
      final aa = (a['amount'] as num?)?.toDouble() ?? 0;
      final bb = (b['amount'] as num?)?.toDouble() ?? 0;
      final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      switch (_sort) {
        case 'amount_desc':
          return bb.compareTo(aa);
        case 'date_desc':
          return db.compareTo(da);
        case 'date_asc':
          return da.compareTo(db);
        case 'amount_asc':
        default:
          return aa.compareTo(bb);
      }
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await apiClient.fetchOffersForListing(widget.listingId);
      setState(() {
        _offers = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklifler alınamadı: ${e.toString()}')),
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
    final filtered = _applyFilters();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Teklifler - ${widget.title}',
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
          if (!_loading && _offers.isNotEmpty)
            Row(
              children: [
                DropdownButton<String>(
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'amount_asc', child: Text('Artan fiyata göre')),
                    DropdownMenuItem(value: 'amount_desc', child: Text('Azalan fiyata göre')),
                    DropdownMenuItem(value: 'date_desc', child: Text('En yeni')),
                    DropdownMenuItem(value: 'date_asc', child: Text('En eski')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _sort = v);
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tümü')),
                    DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                    DropdownMenuItem(value: 'accepted', child: Text('Kabul')),
                    DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bu ilana henüz teklif gelmemiş.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final offer = filtered[index] as Map<String, dynamic>;
                  final amount = offer['amount']?.toString() ?? '-';
                  final status = offer['status']?.toString() ?? 'pending';
                  final id = offer['id']?.toString() ?? '';

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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        '$amount TL',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
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
                          ],
                        ),
                      ),
                      trailing: status == 'pending'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: BiTasiColors.errorRed),
                                  onPressed: () => _updateOffer(id, false),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: BiTasiColors.successGreen),
                                  onPressed: () => _updateOffer(id, true),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateOffer(String offerId, bool accept) async {
    try {
      if (accept) {
        await apiClient.acceptOffer(offerId);
      } else {
        await apiClient.rejectOffer(offerId);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Teklif kabul edildi.' : 'Teklif reddedildi.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem başarısız, tekrar dene.')),
      );
    }
  }
}

class _TimelineStep {
  final String key;
  final String label;
  const _TimelineStep(this.key, this.label);
}