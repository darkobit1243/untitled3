import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/google_places_service.dart';
import '../../services/location_gate.dart';
import '../../services/location_label_cache.dart';
import '../../theme/bitasi_theme.dart';
import '../../utils/image_utils.dart';
import '../../utils/location_utils.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_section_card.dart';
import '../offer_amount_screen.dart';

class IlanlarScreen extends StatefulWidget {
  const IlanlarScreen({super.key});

  @override
  State<IlanlarScreen> createState() => _IlanlarScreenState();
}

class _IlanlarScreenState extends State<IlanlarScreen> with TickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _listings = [];

  final Dio _dio = Dio();
  late final GooglePlacesService _places = GooglePlacesService(_dio);
  final Map<String, String> _pickupLabels = {};
  final Map<String, String> _dropoffLabels = {};
  final Set<String> _inFlight = {};

  @override
  void initState() {
    super.initState();
    _load();
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
      _hydrateListingAddresses(normalized);

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
      _hydrateListingAddresses(enriched);
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

  Future<void> _hydrateListingAddresses(List<Map<String, dynamic>> listings) async {
    // Sequential requests to avoid hammering Geocoding API.
    for (final item in listings) {
      if (!mounted) return;
      final listingId = item['id']?.toString();
      if (listingId == null || listingId.isEmpty) continue;

      await _ensureLocationLabel(
        listingId: listingId,
        locationKey: 'pickup_location',
        cache: _pickupLabels,
      );

      await _ensureLocationLabel(
        listingId: listingId,
        locationKey: 'dropoff_location',
        cache: _dropoffLabels,
      );
    }
  }

  Future<void> _ensureLocationLabel({
    required String listingId,
    required String locationKey,
    required Map<String, String> cache,
  }) async {
    final inflightKey = '$listingId::$locationKey';
    if (cache.containsKey(listingId)) return;
    if (_inFlight.contains(inflightKey)) return;

    final listing = _listings.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id']?.toString() == listingId,
          orElse: () => null,
        );
    if (listing == null) return;

    final locRaw = listing[locationKey];
    if (locRaw is! Map) return;
    final lat = (locRaw['lat'] as num?)?.toDouble();
    final lng = (locRaw['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final persisted = await LocationLabelCache.getLabel(lat: lat, lng: lng);
    if (persisted != null && persisted.trim().isNotEmpty) {
      cache[listingId] = persisted;
      _applyLocationLabelToListing(
        listingId: listingId,
        locationKey: locationKey,
        label: persisted,
      );
      return;
    }

    _inFlight.add(inflightKey);
    try {
      final parts = await _places.reverseGeocodeParts(position: LatLng(lat, lng));
      final label = parts?.toDisplayString();
      if (!mounted) return;
      if (label == null || label.trim().isEmpty) return;

      // Persist across restarts.
      // ignore: unawaited_futures
      LocationLabelCache.setLabel(lat: lat, lng: lng, label: label);

      cache[listingId] = label;
      _applyLocationLabelToListing(
        listingId: listingId,
        locationKey: locationKey,
        label: label,
      );
    } catch (_) {
      // ignore
    } finally {
      _inFlight.remove(inflightKey);
    }
  }

  void _applyLocationLabelToListing({
    required String listingId,
    required String locationKey,
    required String label,
  }) {
    final idx = _listings.indexWhere((e) => e['id']?.toString() == listingId);
    if (idx < 0) return;

    final listing = Map<String, dynamic>.from(_listings[idx]);
    final locRaw = listing[locationKey];
    if (locRaw is! Map) return;

    final loc = Map<String, dynamic>.from(locRaw.map((k, v) => MapEntry(k.toString(), v)));
    final display = loc['display']?.toString();
    if (display != null && display.trim().isNotEmpty) return;

    loc['display'] = label;
    final addr = loc['address']?.toString();
    if (addr == null || addr.trim().isEmpty) {
      loc['address'] = label;
    }

    listing[locationKey] = loc;
    final next = List<Map<String, dynamic>>.from(_listings);
    next[idx] = listing;

    if (mounted) setState(() => _listings = next);
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
              if (data['deliveredCount'] != null) Text('Tamamlanan teslimat: ${data['deliveredCount']}'),
              if (data['address'] != null) Text('Adres: ${data['address']}'),
              if (data['phone'] != null) Text('Telefon: ${data['phone']}'),
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

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.item,
    required this.onDetailPressed,
    required this.onOfferPressed,
    required this.onProfilePressed,
  });

  final Map<String, dynamic> item;
  final VoidCallback onDetailPressed;
  final VoidCallback onOfferPressed;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'İlan';
    final pickup = item['pickup_location']?['display']?.toString() ?? item['pickup_location']?['address']?.toString() ?? 'Kalkış';
    final dropoff = item['dropoff_location']?['display']?.toString() ?? item['dropoff_location']?['address']?.toString() ?? 'Varış';
    final price = item['price']?.toString() ?? '—';
    final weight = item['weight']?.toString() ?? '-';
    final distance = (item['__distance'] as num?)?.toStringAsFixed(1) ?? '–';

    final ownerName = item['ownerName']?.toString() ?? 'Gönderici';
    final ownerAvatar = item['ownerAvatar']?.toString();
    final ownerAvatarProvider = ImageUtils.imageProviderFromString(ownerAvatar);
    final rating = (item['ownerRating'] as num?)?.toDouble();
    final delivered = (item['ownerDelivered'] as num?)?.toInt();
    final ownerInitial = ownerName.isNotEmpty ? ownerName.characters.first.toUpperCase() : 'G';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withAlpha(13),
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
                _pill('$weight kg'),
                const SizedBox(width: 8),
                _chip(distance == '–' ? 'Mesafe yok' : '$distance km'),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onProfilePressed,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: ownerAvatarProvider,
                    child: ownerAvatarProvider == null
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
            _locationRow(icon: Icons.my_location, text: pickup),
            _locationRow(icon: Icons.place, text: dropoff),
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
                  onPressed: onDetailPressed,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                  label: const Text('Detay', style: TextStyle(color: Colors.black87, fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: onOfferPressed,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: BiTasiColors.primaryRed,
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
  }

  Widget _locationRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
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

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ListingDetailSheet extends StatelessWidget {
  const ListingDetailSheet({
    super.key,
    required this.item,
    required this.onClose,
    required this.onOpenPhotoLightbox,
    required this.onOfferPressed,
    required this.onDirectionsPressed,
    required this.onProfilePressed,
  });

  final Map<String, dynamic> item;
  final VoidCallback onClose;
  final Future<void> Function(String url, Object heroTag) onOpenPhotoLightbox;
  final Future<void> Function(String listingId, String title, String? listingOwnerId) onOfferPressed;
  final Future<void> Function(LatLng origin, LatLng destination) onDirectionsPressed;
  final Future<void> Function(String userId) onProfilePressed;

  @override
  Widget build(BuildContext context) {
    final pickupAddress = item['pickup_location']?['display']?.toString() ?? item['pickup_location']?['address']?.toString();
    final dropoffAddress = item['dropoff_location']?['display']?.toString() ?? item['dropoff_location']?['address']?.toString();
    final pickup = pickupAddress?.trim().isNotEmpty == true ? pickupAddress! : 'Kalkış';
    final dropoff = dropoffAddress?.trim().isNotEmpty == true ? dropoffAddress! : 'Varış';

    final price = item['price']?.toString() ?? '—';
    final weight = item['weight']?.toString() ?? '-';
    final distance = (item['__distance'] as num?)?.toStringAsFixed(1) ?? '–';

    final listingId = item['id']?.toString() ?? '';
    final listingOwnerId = item['ownerId']?.toString();

    final title = item['title']?.toString() ?? 'İlan';
    final photos = ImageUtils.photosFromListing(item);

    final from = LocationUtils.latLngFromLocation(item['pickup_location']);
    final to = LocationUtils.latLngFromLocation(item['dropoff_location']);

    final singlePhotoUrl = photos.length == 1 ? photos.first : null;
    final singleHeroTag = singlePhotoUrl == null ? null : 'listing_photo_${listingId.isEmpty ? singlePhotoUrl : listingId}_0';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            if (singlePhotoUrl != null && singleHeroTag != null) ...[
              const SizedBox(height: 10),
              AppSectionCard(
                padding: const EdgeInsets.all(10),
                child: GestureDetector(
                  onTap: () => onOpenPhotoLightbox(singlePhotoUrl, singleHeroTag),
                  child: Hero(
                    tag: singleHeroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: ImageUtils.imageWidgetFromString(singlePhotoUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (photos.length > 1) ...[
              const SizedBox(height: 10),
              AppSectionCard(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final url = photos[index];
                      final heroTag = 'listing_photo_${listingId.isEmpty ? url : listingId}_$index';
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: GestureDetector(
                            onTap: () => onOpenPhotoLightbox(url, heroTag),
                            child: Hero(
                              tag: heroTag,
                              child: ImageUtils.imageWidgetFromString(url, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _infoRow(Icons.my_location, 'Kalkış', pickup),
            _infoRow(Icons.place, 'Varış', dropoff),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('$weight kg'),
                _chip(distance == '–' ? 'Mesafe yok' : '$distance km'),
              ],
            ),
            if (from != null && to != null) ...[
              const SizedBox(height: 12),
              AppSectionCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 160,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: from, zoom: 10),
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          compassEnabled: false,
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          liteModeEnabled: true,
                          markers: {
                            Marker(
                              markerId: const MarkerId('pickup'),
                              position: from,
                              infoWindow: const InfoWindow(title: 'Kalkış'),
                            ),
                            Marker(
                              markerId: const MarkerId('dropoff'),
                              position: to,
                              infoWindow: const InfoWindow(title: 'Varış'),
                            ),
                          },
                          polylines: {
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: [from, to],
                              color: BiTasiColors.primaryRed,
                              width: 4,
                            ),
                          },
                          onMapCreated: (c) async {
                            final bounds = LocationUtils.boundsFromTwoPoints(from, to);
                            // ignore: avoid_redundant_argument_values
                            await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 42));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Theme(
                      data: Theme.of(context).copyWith(
                        elevatedButtonTheme: ElevatedButtonThemeData(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BiTasiColors.primaryRed,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      child: AppButton.primary(
                        label: 'Yol tarifi al',
                        onPressed: () => onDirectionsPressed(from, to),
                        height: 48,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Detaylar için gönderici ile mesajlaşabilirsiniz.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (listingOwnerId != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onProfilePressed(listingOwnerId),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profili Gör'),
                ),
              ),
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BiTasiColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: 'Teklif Ver',
                  onPressed: listingId.isEmpty ? null : () => onOfferPressed(listingId, title, listingOwnerId),
                  height: 52,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
}
