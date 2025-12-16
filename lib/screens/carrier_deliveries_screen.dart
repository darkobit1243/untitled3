import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../services/api_client.dart';
import '../services/location_gate.dart';
import 'live_tracking_screen.dart';
import 'qr_scan_screen.dart';
import '../theme/trustship_theme.dart';

class CarrierDeliveriesScreen extends StatefulWidget {
  const CarrierDeliveriesScreen({super.key});

  @override
  State<CarrierDeliveriesScreen> createState() => _CarrierDeliveriesScreenState();
}

class _CarrierDeliveriesScreenState extends State<CarrierDeliveriesScreen> {
  bool _loading = true;
  List<dynamic> _items = [];

  final Set<String> _ratedDeliveryIds = <String>{};

  final Map<String, Timer> _autoTrackTimers = <String, Timer>{};
  bool _locationPermissionChecked = false;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _autoTrackTimers.values) {
      t.cancel();
    }
    _autoTrackTimers.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await apiClient.fetchCarrierDeliveries();

      final ratedIds = <String>{};
      try {
        final mine = await apiClient.fetchMyGivenRatings();
        for (final r in mine) {
          if (r is Map<String, dynamic>) {
            final deliveryId = r['deliveryId']?.toString() ?? '';
            if (deliveryId.isNotEmpty) ratedIds.add(deliveryId);
          }
        }
      } catch (_) {
        // Ignore
      }

      setState(() {
        _items = data;
        _ratedDeliveryIds
          ..clear()
          ..addAll(ratedIds);
      });
      _syncAutoTracking();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teslimatlar alınamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showRatingDialog({required String deliveryId, required String listingId}) async {
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
                  color: TrustShipColors.warningOrange,
                ),
              );
            }

            return AlertDialog(
              title: Text('Puan Ver: $listingId'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Göndericiyi değerlendir', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: TrustShipColors.primaryRed),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teslimatlarım')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Henüz sana atanmış teslimat yok.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index] as Map<String, dynamic>;
                      final id = item['id']?.toString() ?? '';
                      final listingId = item['listingId']?.toString() ?? '';
                      final status = item['status']?.toString() ?? '';
                      final pickupAt = item['pickupAt']?.toString() ?? '';
                      final deliveredAt = item['deliveredAt']?.toString() ?? '';

                      String statusLabel;
                      Color statusColor;
                      if (status == 'pickup_pending') {
                        statusLabel = 'Alım bekleniyor';
                        statusColor = TrustShipColors.warningOrange;
                      } else if (status == 'in_transit') {
                        statusLabel = 'Yolda';
                        statusColor = TrustShipColors.primaryRed;
                      } else if (status == 'delivered') {
                        statusLabel = 'Teslim edildi';
                        statusColor = TrustShipColors.successGreen;
                      } else {
                        statusLabel = 'Bilinmiyor';
                        statusColor = Colors.grey;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: TrustShipColors.backgroundGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_shipping, color: TrustShipColors.primaryRed),
                          ),
                          title: Text(
                            'Listing: $listingId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pickupAt.isNotEmpty)
                                Text(
                                  'Alındı: $pickupAt',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              if (deliveredAt.isNotEmpty)
                                Text(
                                  'Teslim: $deliveredAt',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  // ignore: deprecated_member_use
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (status == 'pickup_pending')
                                TextButton(
                                  onPressed: () => _updateStatus(id, true),
                                  child: const Text(
                                    'Teslimatı Al',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                )
                              else if (status == 'in_transit')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _sendLocation(id),
                                      child: const Text('Konumu Gönder', style: TextStyle(fontSize: 11)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => LiveTrackingScreen(deliveryId: id),
                                          ),
                                        );
                                      },
                                      child: const Text('Canlı Takip', style: TextStyle(fontSize: 11)),
                                    ),
                                    TextButton(
                                      onPressed: () => _updateStatus(id, false),
                                      child: const Text('Teslim Et', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              if (status == 'delivered')
                                TextButton(
                                  onPressed: _ratedDeliveryIds.contains(id)
                                      ? null
                                      : () => _showRatingDialog(deliveryId: id, listingId: listingId),
                                  child: Text(
                                    _ratedDeliveryIds.contains(id) ? 'Puanlandı' : 'Puan Ver',
                                    style: const TextStyle(fontSize: 11),
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

  Future<void> _updateStatus(String deliveryId, bool pickup) async {
    try {
      if (pickup) {
        final qr = await Navigator.of(context).push<String?>(
          MaterialPageRoute<String?>(
            builder: (_) => const QrScanScreen(),
          ),
        );
        if (qr == null || qr.trim().isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR okutulmadan devam edemezsiniz.')),
          );
          return;
        }
        await apiClient.pickupDeliveryWithQr(deliveryId, qrToken: qr.trim());
      } else {
        await apiClient.deliverDelivery(deliveryId);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pickup ? 'Teslimat alındı.' : 'Teslim edildi.'),
        ),
      );

      if (pickup) {
        // QR doğrulaması başarılı -> takip aktif. Doğrudan canlı takip ekranına geç.
        // ignore: use_build_context_synchronously
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LiveTrackingScreen(deliveryId: deliveryId),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  void _syncAutoTracking() {
    // Start tracking timers for in_transit deliveries; stop for others.
    final inTransitIds = _items
        .whereType<Map<String, dynamic>>()
        .where((d) => (d['status']?.toString() ?? '') == 'in_transit')
        .map((d) => d['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final toStop = _autoTrackTimers.keys.where((id) => !inTransitIds.contains(id)).toList();
    for (final id in toStop) {
      _autoTrackTimers[id]?.cancel();
      _autoTrackTimers.remove(id);
    }

    for (final id in inTransitIds) {
      _autoTrackTimers.putIfAbsent(id, () {
        // Send immediately, then every 15s.
        _sendLocationSilently(id);
        return Timer.periodic(const Duration(seconds: 15), (_) => _sendLocationSilently(id));
      });
    }
  }

  Future<bool> _ensureLocationPermissionSilent() async {
    if (_locationPermissionChecked) return _locationPermissionGranted;
    _locationPermissionChecked = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationPermissionGranted = false;
        return false;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      _locationPermissionGranted = !(permission == LocationPermission.denied || permission == LocationPermission.deniedForever);
      return _locationPermissionGranted;
    } catch (_) {
      _locationPermissionGranted = false;
      return false;
    }
  }

  Future<void> _sendLocationSilently(String deliveryId) async {
    if (!mounted) return;
    final ok = await _ensureLocationPermissionSilent();
    if (!ok) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );
      await apiClient.updateDeliveryLocation(deliveryId, lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // Silent fail (no UI noise)
    }
  }

  Future<void> _sendLocation(String deliveryId) async {
    try {
      final ok = await LocationGate.ensureReady(
        context: context,
        userInitiated: true,
      );
      if (!ok) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );

      await apiClient.updateDeliveryLocation(deliveryId, lat: pos.latitude, lng: pos.longitude);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum gönderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum gönderilemedi: $e')),
      );
    }
  }
}
