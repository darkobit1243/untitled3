import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../models/delivery_status.dart';
import '../../services/api_client.dart';
import '../../services/background_tracking_service.dart';
import '../../services/location_gate.dart';
import '../../theme/bitasi_theme.dart';
import 'carrier_delivery_details_screen.dart';
import '../live_tracking_screen.dart';
import '../qr_scan_screen.dart';

class CarrierDeliveriesScreen extends StatefulWidget {
  const CarrierDeliveriesScreen({super.key});

  @override
  State<CarrierDeliveriesScreen> createState() => _CarrierDeliveriesScreenState();
}

class _CarrierDeliveriesScreenState extends State<CarrierDeliveriesScreen> {
  bool _loading = true;
  List<dynamic> _items = [];

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
      setState(() {
        _items = data;
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

  @override
  Widget build(BuildContext context) {
    final maps = _items.whereType<Map<String, dynamic>>().toList();
    bool isActive(Map<String, dynamic> d) {
      final s = d['status']?.toString().toLowerCase() ?? '';
      return s == DeliveryStatus.pickupPending || s == DeliveryStatus.inTransit || s == DeliveryStatus.atDoor;
    }

    final activeItems = maps.where(isActive).toList();
    final pastItems = maps.where((d) => !isActive(d)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teslimatlarım'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aktif Teslimatlarım'),
              Tab(text: 'Geçmiş Teslimatlarım'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildDeliveryList(
                      items: activeItems,
                      emptyText: _items.isEmpty
                          ? 'Henüz sana atanmış teslimat yok.'
                          : 'Aktif teslimatın yok.',
                    ),
                    _buildDeliveryList(
                      items: pastItems,
                      emptyText: _items.isEmpty
                          ? 'Henüz sana atanmış teslimat yok.'
                          : 'Geçmiş teslimatın yok.',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDeliveryList({required List<Map<String, dynamic>> items, required String emptyText}) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildDeliveryCard(items[index]);
      },
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final listingId = item['listingId']?.toString() ?? '';
    final listing = (item['listing'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
    final title = listing?['title']?.toString().trim();
    final status = item['status']?.toString().toLowerCase() ?? '';
    final receiverPhone = item['receiver_phone']?.toString() ?? '';
    final pickupAt = item['pickupAt']?.toString() ?? '';
    final deliveredAt = item['deliveredAt']?.toString() ?? '';

    String formatDateTimeOrRaw(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return '';
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return value;
      final local = parsed.toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(local);
    }

    final pickupAtLabel = formatDateTimeOrRaw(pickupAt);
    final deliveredAtLabel = formatDateTimeOrRaw(deliveredAt);

    String shortId(String value, {int len = 6}) {
      final v = value.trim();
      if (v.isEmpty) return '';
      return v.length <= len ? v : v.substring(0, len);
    }

    final resolvedListingId = (listing?['id']?.toString() ?? listingId).trim();
    final resolvedTitle = (title ?? '').trim();
    final cardTitle = resolvedTitle.isNotEmpty
      ? resolvedTitle
      : (resolvedListingId.isNotEmpty
        ? 'İlan #${shortId(resolvedListingId)}'
        : (id.isNotEmpty ? 'Teslimat #${shortId(id)}' : 'Teslimat'));

    final subtitle = receiverPhone.trim().isNotEmpty
      ? 'Alıcı: $receiverPhone'
      : (resolvedListingId.isNotEmpty ? 'İlan: ${shortId(resolvedListingId)}' : '');

    String statusLabel;
    Color statusColor;
    if (status == DeliveryStatus.pickupPending) {
      statusLabel = 'Alım bekleniyor';
      statusColor = BiTasiColors.warningOrange;
    } else if (status == DeliveryStatus.inTransit) {
      statusLabel = 'Yolda';
      statusColor = BiTasiColors.primaryRed;
    } else if (status == DeliveryStatus.atDoor) {
      statusLabel = 'Kapıda';
      statusColor = BiTasiColors.warningOrange;
    } else if (status == DeliveryStatus.delivered) {
      statusLabel = 'Teslim edildi';
      statusColor = BiTasiColors.successGreen;
    } else if (status == DeliveryStatus.cancelled) {
      statusLabel = 'İptal';
      statusColor = Colors.grey;
    } else if (status == DeliveryStatus.disputed) {
      statusLabel = 'Uyuşmazlık';
      statusColor = BiTasiColors.errorRed;
    } else {
      statusLabel = 'Bilinmiyor';
      statusColor = Colors.grey;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CarrierDeliveryDetailsScreen(delivery: item),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: BiTasiColors.backgroundGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping, color: BiTasiColors.primaryRed),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (receiverPhone.trim().isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Alıcı: $receiverPhone',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (pickupAtLabel.isNotEmpty || deliveredAtLabel.isNotEmpty) ...[
              if (receiverPhone.trim().isNotEmpty) const SizedBox(height: 6),
              if (pickupAtLabel.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alındı: $pickupAtLabel',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (deliveredAtLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Teslim: $deliveredAtLabel',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (status == DeliveryStatus.pickupPending ||
                status == DeliveryStatus.inTransit ||
                status == DeliveryStatus.atDoor ||
                status == DeliveryStatus.delivered) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (status == DeliveryStatus.pickupPending)
                    FilledButton(
                      onPressed: () => _updateStatus(id, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: BiTasiColors.primaryRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Teslimatı Al'),
                    ),
                  if (status == DeliveryStatus.inTransit || status == DeliveryStatus.atDoor) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LiveTrackingScreen(deliveryId: id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_searching, size: 18),
                      label: const Text('Takip'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _markDeliveredFromSendCode(id),
                      icon: const Icon(Icons.sms_outlined, size: 18),
                      label: const Text('Kod Gönder'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            ],
          ),
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
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pickup ? 'Teslimat alındı.' : 'İşlem tamamlandı.'),
        ),
      );

      if (pickup) {
        // Pickup sonrası canlı takip otomatik çalışacak (15sn). İzin yoksa burada isteyelim.
        final ok = await LocationGate.ensureReady(
          context: context,
          userInitiated: true,
        );
        if (ok) {
          // Permission cache'i sıfırla; ilk konumu hemen gönder.
          _locationPermissionChecked = false;
          // ignore: unawaited_futures
          _sendLocationSilently(deliveryId);

          // Also start background tracking for this delivery.
          // ignore: unawaited_futures
          BackgroundTrackingService.syncDeliveries(<String>{deliveryId});
        }

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

  // ignore: unused_element
  Future<void> _confirmDeliveryWithFirebase(String deliveryId, String receiverPhone) async {
    final phone = receiverPhone.trim();
    if (phone.isEmpty) return;

    String? verificationId;
    String? failure;

    try {
      final auth = FirebaseAuth.instance;

      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCred = await auth.signInWithCredential(credential);
          final token = await userCred.user?.getIdToken();
          if (token == null || token.isEmpty) {
            throw Exception('Firebase token alınamadı');
          }
          await apiClient.confirmDeliveryWithFirebase(deliveryId, idToken: token);
          await auth.signOut();
        },
        verificationFailed: (FirebaseAuthException e) {
          failure = e.message ?? e.code;
        },
        codeSent: (String vId, int? resendToken) {
          verificationId = vId;
        },
        codeAutoRetrievalTimeout: (String vId) {
          verificationId = vId;
        },
      );

      if (failure != null) {
        throw Exception(failure);
      }

      final vId = verificationId;
      if (vId == null || vId.isEmpty) {
        // Auto verification may have completed already.
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kod gönderildi. Otomatik doğrulama deneniyor...')),
        );
        return;
      }

      final smsCode = await _promptForSmsCode();
      if (smsCode == null || smsCode.trim().isEmpty) return;

      final credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: smsCode.trim(),
      );
      final userCred = await auth.signInWithCredential(credential);
      final token = await userCred.user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('Firebase token alınamadı');
      }
      await apiClient.confirmDeliveryWithFirebase(deliveryId, idToken: token);
      await auth.signOut();

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teslimat onaylandı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod gönderme/onay başarısız: $e')),
      );
    }
  }

  Future<void> _markDeliveredFromSendCode(String deliveryId) async {
    try {
      await apiClient.sendDeliveryCode(deliveryId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teslimat teslim edildi olarak işaretlendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  Future<String?> _promptForSmsCode() async {
    final controller = TextEditingController();
    String? result;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Teslimat Kodu'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'SMS ile gelen kod',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                result = controller.text;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  void _syncAutoTracking() {
    // Start tracking timers for in_transit deliveries; stop for others.
    final inTransitIds = _items
        .whereType<Map<String, dynamic>>()
        .where((d) {
          final s = (d['status']?.toString().toLowerCase() ?? '');
          return s == DeliveryStatus.inTransit || s == DeliveryStatus.atDoor;
        })
        .map((d) => d['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // Background tracking (15s). Android uses a foreground service; iOS is OS-controlled.
    // ignore: unawaited_futures
    BackgroundTrackingService.syncDeliveries(inTransitIds);

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
    final ok = await _ensureLocationPermissionSilent();
    if (!ok) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );

      await apiClient.updateDeliveryLocation(deliveryId, lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // Silent fail.
    }
  }
}
