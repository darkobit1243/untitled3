import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/google_places_service.dart';
import '../../services/location_gate.dart';
import '../../utils/carrier/image_utils.dart';
import '../../utils/carrier/location_utils.dart';
import '../../utils/carrier/ilanlar/listing_location_label_hydrator.dart';
import '../../widgets/carrier/ilanlar/listing_card.dart';
import '../../widgets/carrier/ilanlar/listing_detail_sheet.dart';
import '../../widgets/carrier/ilanlar/user_profile_sheet.dart';
import '../offer_amount_screen.dart';

class IlanlarScreen extends StatefulWidget {
  const IlanlarScreen({super.key});

  @override
  State<IlanlarScreen> createState() => _IlanlarScreenState();
}

class _IlanlarScreenState extends State<IlanlarScreen> with TickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _listings = [];

  int _hydrateRunId = 0;

  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  late final ListingLocationLabelHydrator _labelHydrator = ListingLocationLabelHydrator(places: _places);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Cancel any in-flight background hydration.
    _hydrateRunId++;
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final currentFuture = _tryGetCurrentLocation();
      final data = await apiClient.fetchListings();
      final normalized = data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

      // Show listings immediately; don't block on location.
      if (!mounted) return;
      setState(() {
        _listings = normalized;
      });

      // Fill pickup/dropoff labels in the background.
      // ignore: unawaited_futures
      final runId = ++_hydrateRunId;
      _hydrateListingAddresses(normalized, runId);

      final current = await currentFuture;
      if (!mounted || current == null) return;

      final enriched = normalized.map((l) {
        final copy = Map<String, dynamic>.from(l);
        final distanceKm = LocationUtils.distanceKmToPickup(listing: copy, current: current);
        if (distanceKm != null) {
          copy['__distance'] = distanceKm;
        }
        return copy;
      }).toList();

      enriched.sort((a, b) {
        final da = (a['__distance'] as num?)?.toDouble() ?? double.infinity;
        final db = (b['__distance'] as num?)?.toDouble() ?? double.infinity;
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() => _listings = enriched);

      // Keep hydrating with the enriched list (sorted etc).
      // ignore: unawaited_futures
      _hydrateListingAddresses(enriched, runId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İlanlar alınamadı: $e')),
      );
      setState(() {
        _listings = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hydrateListingAddresses(List<Map<String, dynamic>> listings, int runId) async {
    await _labelHydrator.hydrateListingAddresses(
      listings: listings,
      runId: runId,
      currentRunId: () => _hydrateRunId,
      isMounted: () => mounted,
      onLabel: ({required listingId, required locationKey, required label}) {
        final next = applyLocationLabelToListings(
          listings: _listings,
          listingId: listingId,
          locationKey: locationKey,
          label: label,
        );
        if (next != null && mounted) {
          setState(() => _listings = next);
        }
      },
    );
  }

  Future<void> _tryOpenOfferForListing({
    required String listingId,
    required String title,
    required String? listingOwnerId,
  }) async {
    if (listingId.isEmpty) return;

    String? currentUserId;
    try {
      currentUserId = await apiClient.getCurrentUserId();
    } catch (_) {
      currentUserId = null;
    }

    if (currentUserId != null && listingOwnerId != null && currentUserId == listingOwnerId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz.')),
      );
      return;
    }

    await _showOfferSheet(listingId, title);
  }

  Future<Position?> _tryGetCurrentLocation() async {
    try {
      final ok = await LocationGate.ensureReady(context: context, userInitiated: false);
      if (!ok) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openGoogleMapsDirections({required LatLng origin, required LatLng destination}) async {
    final uri = LocationUtils.googleMapsDirectionsUri(origin: origin, destination: destination);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps açılamadı.')),
      );
    }
  }

  Future<void> _openPhotoLightbox({required String url, required Object heroTag}) async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fotoğraf',
      barrierColor: Colors.black.withAlpha(40),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, __, ___) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.black.withAlpha(110)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ImageUtils.imageWidgetFromString(url, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 10,
                  child: SafeArea(
                    child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showOfferSheet(String listingId, String title) async {
    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        pageBuilder: (_, __, ___) => OfferAmountScreen(title: title),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (!mounted) return;
    if (result == null || result.trim().isEmpty) return;

    final normalized = result.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin.')),
      );
      return;
    }

    try {
      await apiClient.createOffer(listingId: listingId, amount: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif gönderildi.')),
      );
      // Refresh: listing may disappear after acceptance.
      // ignore: unawaited_futures
      _load();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('zaten kabul edilmiş')
          ? 'Bu ilan için teklif kabul edilmiş. Artık teklif verilemez.'
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklif gönderilemedi: $msg')),
      );
      // Also refresh to remove stale items.
      // ignore: unawaited_futures
      _load();
    }
  }

  void _showDetailSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return ListingDetailSheet(
          item: item,
          onClose: () => Navigator.pop(ctx),
          onOpenPhotoLightbox: (url, heroTag) => _openPhotoLightbox(url: url, heroTag: heroTag),
          onOfferPressed: (listingId, title, listingOwnerId) => _tryOpenOfferForListing(
            listingId: listingId,
            title: title,
            listingOwnerId: listingOwnerId,
          ),
          onDirectionsPressed: (origin, destination) => _openGoogleMapsDirections(origin: origin, destination: destination),
          onProfilePressed: _openProfile,
        );
      },
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
        builder: (_) => UserProfileSheet(data: Map<String, dynamic>.from(data)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil alınamadı: $e')),
      );
    }
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
                                final item = _listings[index];
                                final title = item['title']?.toString() ?? 'İlan';

                                return ListingCard(
                                  item: item,
                                  onDetailPressed: () => _showDetailSheet(item),
                                  onOfferPressed: () => _tryOpenOfferForListing(
                                    listingId: item['id']?.toString() ?? '',
                                    title: title,
                                    listingOwnerId: item['ownerId']?.toString(),
                                  ),
                                  onProfilePressed: () {
                                    final ownerId = item['ownerId']?.toString();
                                    if (ownerId == null || ownerId.isEmpty) return;
                                    _openProfile(ownerId);
                                  },
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
