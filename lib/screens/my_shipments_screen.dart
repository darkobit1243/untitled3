import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../services/google_places_service.dart';
import 'live_tracking_screen.dart';
import '../theme/bitasi_theme.dart';
import '../widgets/my_shipments/offers_for_listing_sheet.dart';
import '../widgets/my_shipments/delivery_card.dart';
import '../widgets/my_shipments/listing_card.dart';
import '../widgets/my_shipments/pickup_qr_dialog.dart';
import '../widgets/my_shipments/rating_dialog.dart';
import '../utils/my_shipments/merge_my_shipments_data.dart';
import '../utils/my_shipments/location_label_hydrator.dart';

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

  int _hydrateRunId = 0;

  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  late final MyShipmentsLocationLabelHydrator _labelHydrator =
      MyShipmentsLocationLabelHydrator(places: _places);

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
    // Cancel any in-flight background hydration.
    _hydrateRunId++;
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
      List<dynamic> listingsData = [];
      List<dynamic> deliveriesData = [];
      List<dynamic> mineRatings = [];

      try {
        // Fetch listings + deliveries + my ratings concurrently.
        final results = await Future.wait<dynamic>([
          apiClient.fetchMyListings(),
          apiClient.fetchSenderDeliveries(),
          apiClient.fetchMyGivenRatings().catchError((_) => <dynamic>[]),
        ]);

        listingsData = results[0] is List ? List<dynamic>.from(results[0] as List) : <dynamic>[];
        deliveriesData = results[1] is List ? List<dynamic>.from(results[1] as List) : <dynamic>[];
        mineRatings = results[2] is List ? List<dynamic>.from(results[2] as List) : <dynamic>[];
      } catch (e) {
        // Network error -> Try cache
        listingsData = await apiClient.getMyListingsCache();
        deliveriesData = await apiClient.getSenderDeliveriesCache();
        // Ratings cache is not critical, skip it or add cache support later if needed.

        if (listingsData.isEmpty && deliveriesData.isEmpty) {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Bağlantı yok ve kayıtlı veri bulunamadı.')),
           );
           setState(() => _isLoading = false);
           return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Offline moddasınız. Kayıtlı veriler gösteriliyor.'),
               backgroundColor: BiTasiColors.warningOrange,
             ),
          );
        }
      }

      final merged = mergeMyShipmentsData(
        listingsData: listingsData,
        deliveriesData: deliveriesData,
        mineRatings: mineRatings,
      );

      _syncOfferSubscriptions(listingsData);

      if (!mounted) return;
      setState(() {
        _activeListings = merged.activeItems;
        _historyListings = merged.historyItems;
        _ratedDeliveryIds
          ..clear()
          ..addAll(merged.ratedDeliveryIds);
      });

      // Fill pickup/dropoff labels in the background.
      // ignore: unawaited_futures
      final runId = ++_hydrateRunId;
      _hydrateAddressLabels(runId);

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

  Future<void> _hydrateAddressLabels(int runId) async {
    final items = <dynamic>[..._activeListings, ..._historyListings];
    await _labelHydrator.hydrateAddressLabels(
      items: items,
      runId: runId,
      currentRunId: () => _hydrateRunId,
      isMounted: () => mounted,
      requestRebuild: () => setState(() {}),
    );
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
        final type = item['type']?.toString();
        final data = item['data'] as Map<String, dynamic>;

        if (type == 'listing') {
          final id = data['id']?.toString();
          if (id == targetId) {
            title = data['title']?.toString() ?? 'Gönderi';
            break;
          }
        } else if (type == 'delivery') {
          final listing = asStringMap(data['listing']);
          final id = data['listingId']?.toString() ?? listing?['id']?.toString();
          if (id == targetId) {
            title = listing?['title']?.toString() ?? 'Gönderi';
            break;
          }
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
          return OffersForListingSheet(listingId: listingId, title: title);
        },
      );
    } finally {
      transitionController.dispose();
    }
  }

  void _syncOfferSubscriptions(List<dynamic> listingsData) {
    final listingIds = listingsData
        .map((e) => asStringMap(e)?['id']?.toString() ?? '')
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
    final messenger = ScaffoldMessenger.of(context);
    await showRatingDialog(
      context: context,
      title: title,
      onSubmit: (score) => apiClient.createRating(deliveryId: deliveryId, score: score),
      onSuccess: () {
        messenger.showSnackBar(const SnackBar(content: Text('Puanın kaydedildi.')));
        // ignore: unawaited_futures
        _load();
      },
    );
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
          final deliveryId = data['id']?.toString() ?? '';
          return MyShipmentsDeliveryCard(
            delivery: data,
            isRated: deliveryId.isNotEmpty && _ratedDeliveryIds.contains(deliveryId),
            onShowPickupQr: (token) => _showPickupQr(context, token),
            onOpenLiveTracking: (id) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LiveTrackingScreen(deliveryId: id),
                ),
              );
            },
            onRate: (id, title) => _showRatingDialog(deliveryId: id, title: title),
            onOpenDetails: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gönderi detayları yakında eklenecek')),
            ),
          );
        } else {
          final listingId = data['id']?.toString() ?? '';
          final hasOfferBadge = listingId.isNotEmpty && _offerBadgeListingIds.contains(listingId);
          return MyShipmentsListingCard(
            listing: data,
            hasOfferBadge: hasOfferBadge,
            onOpenOffers: _openOffersForListing,
          );
        }
      },
    );
  }

  void _showPickupQr(BuildContext context, String token) {
    // ignore: unawaited_futures
    showPickupQrDialog(context, token);
  }

}