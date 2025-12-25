import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/bitasi_theme.dart';
import '../../../utils/carrier/image_utils.dart';
import '../../../utils/carrier/location_utils.dart';
import '../../common/app_button.dart';
import '../../common/app_section_card.dart';

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
    final singleHeroTag =
        singlePhotoUrl == null ? null : 'listing_photo_${listingId.isEmpty ? singlePhotoUrl : listingId}_0';

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
