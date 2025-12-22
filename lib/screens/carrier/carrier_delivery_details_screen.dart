import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import '../../utils/image_utils.dart';
import '../live_tracking_screen.dart';

class CarrierDeliveryDetailsScreen extends StatefulWidget {
  const CarrierDeliveryDetailsScreen({
    super.key,
    required this.delivery,
  });

  final Map<String, dynamic> delivery;

  @override
  State<CarrierDeliveryDetailsScreen> createState() => _CarrierDeliveryDetailsScreenState();
}

class _CarrierDeliveryDetailsScreenState extends State<CarrierDeliveryDetailsScreen> {
  Map<String, dynamic>? _listing;
  bool _loadingListing = false;
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _listing = (widget.delivery['listing'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
    if (_listing == null) {
      _loadListing();
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    final listingId = widget.delivery['listingId']?.toString() ?? '';
    if (listingId.isEmpty) return;
    setState(() {
      _loadingListing = true;
    });
    try {
      final l = await apiClient.fetchListingById(listingId);
      if (!mounted) return;
      setState(() {
        _listing = l;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İlan detayı alınamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingListing = false;
        });
      }
    }
  }

  LatLng? _tryParseLatLng(dynamic json) {
    if (json is! Map) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  Future<void> _openDirections({required LatLng origin, required LatLng dest}) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}'
      '&destination=${dest.latitude},${dest.longitude}&travelmode=driving',
    );
    if (!await canLaunchUrl(uri)) {
      throw Exception('Harita uygulaması açılamadı');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPhotoLightbox({required String url, required Object heroTag}) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'photo',
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.black.withAlpha(140)),
                ),
                Center(
                  child: Hero(
                    tag: heroTag,
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImageUtils.imageWidgetFromString(url, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryId = widget.delivery['id']?.toString() ?? '';
    final listingId = widget.delivery['listingId']?.toString() ?? '';
    final status = widget.delivery['status']?.toString().toLowerCase() ?? '';
    final trackingEnabled = widget.delivery['trackingEnabled'] == true;

    final listing = _listing;
    final showStage = status == 'pickup_pending' || status == 'in_transit' || status == 'at_door';
    final stageLabel = status == 'in_transit' ? 'Yolda' : 'Teslim edilecek';
    final stageColor = status == 'in_transit' ? BiTasiColors.primaryRed : BiTasiColors.warningOrange;

    final pickup = _tryParseLatLng(listing?['pickup_location']);
    final dropoff = _tryParseLatLng(listing?['dropoff_location']);

    final photos = listing == null ? <String>[] : ImageUtils.photosFromListing(listing);

    final markers = <Marker>{
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Alım noktası'),
        ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          infoWindow: const InfoWindow(title: 'Teslim noktası'),
        ),
    };

    final polylines = <Polyline>{
      if (pickup != null && dropoff != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: [pickup, dropoff],
          width: 4,
          color: BiTasiColors.primaryRed,
        ),
    };

    final origin = pickup;
    final dest = dropoff;
    final hasRoute = origin != null && dest != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teslimat Detayı'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadingListing ? null : _loadListing,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (showStage)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: stageColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.local_shipping_outlined, color: stageColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stageLabel,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Teslimat akışı',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_loadingListing) ...[
            const SizedBox(height: 12),
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          ],

          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionTitle('Fotoğraflar'),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final url = photos[i];
                  final heroTag = 'delivery_listing_${listingId.isEmpty ? url : listingId}_$i';
                  return GestureDetector(
                    onTap: () => _openPhotoLightbox(url: url, heroTag: heroTag),
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ImageUtils.imageWidgetFromString(url, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),
          _SectionTitle('Rota'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickup ?? dropoff ?? const LatLng(41.0082, 28.9784),
                  zoom: 11,
                ),
                onMapCreated: (c) {
                  _map = c;
                  if (pickup != null && dropoff != null) {
                    final sw = LatLng(
                      (pickup.latitude < dropoff.latitude) ? pickup.latitude : dropoff.latitude,
                      (pickup.longitude < dropoff.longitude) ? pickup.longitude : dropoff.longitude,
                    );
                    final ne = LatLng(
                      (pickup.latitude > dropoff.latitude) ? pickup.latitude : dropoff.latitude,
                      (pickup.longitude > dropoff.longitude) ? pickup.longitude : dropoff.longitude,
                    );
                    // ignore: unawaited_futures
                    c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 60));
                  }
                },
                markers: markers,
                polylines: polylines,
                zoomControlsEnabled: false,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: hasRoute
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _openDirections(origin: origin, dest: dest);
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Yol tarifi açılamadı: $e')),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.directions),
                label: const Text('Yol Tarifi Al'),
                style: FilledButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
              ),
              OutlinedButton.icon(
                onPressed: trackingEnabled && deliveryId.isNotEmpty
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LiveTrackingScreen(deliveryId: deliveryId),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.location_searching),
                label: const Text('Canlı Takip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}
