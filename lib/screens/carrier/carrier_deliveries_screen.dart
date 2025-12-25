import 'package:flutter/material.dart';

import '../../models/delivery_status.dart';
import '../../services/api_client.dart';
import '../../services/background_tracking_service.dart';
import '../../utils/carrier/deliveries/carrier_deliveries_auto_tracker.dart';
import '../../widgets/carrier/deliveries/carrier_delivery_card.dart';
import '../live_tracking_screen.dart';
import '../qr_scan_screen.dart';
import 'carrier_delivery_details_screen.dart';

class CarrierDeliveriesScreen extends StatefulWidget {
  const CarrierDeliveriesScreen({super.key});

  @override
  State<CarrierDeliveriesScreen> createState() => _CarrierDeliveriesScreenState();
}

class _CarrierDeliveriesScreenState extends State<CarrierDeliveriesScreen> {
  bool _loading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Keep parity with older behavior: stop auto tracking when leaving.
    // ignore: unawaited_futures
    BackgroundTrackingService.syncDeliveries(<String>{});
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await apiClient.fetchCarrierDeliveries();
      if (!mounted) return;
      setState(() => _items = data);
      await _syncAutoTracking();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teslimatlar alınamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncAutoTracking() async {
    if (!mounted) return;
    final deliveries = _items.whereType<Map<String, dynamic>>().toList();
    await CarrierDeliveriesAutoTracker.syncFromDeliveries(
      deliveries,
      context: context,
      userInitiated: false,
    );
  }

  bool _isActive(Map<String, dynamic> delivery) {
    final s = delivery['status']?.toString().toLowerCase() ?? '';
    return s == DeliveryStatus.pickupPending || s == DeliveryStatus.inTransit || s == DeliveryStatus.atDoor;
  }

  @override
  Widget build(BuildContext context) {
    final maps = _items.whereType<Map<String, dynamic>>().toList();
    final activeItems = maps.where(_isActive).toList();
    final pastItems = maps.where((d) => !_isActive(d)).toList();

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

  Widget _buildDeliveryList({
    required List<Map<String, dynamic>> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['id']?.toString() ?? '';
        return CarrierDeliveryCard(
          item: item,
          onOpenDetails: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CarrierDeliveryDetailsScreen(delivery: item),
              ),
            );
          },
          onOpenLiveTracking: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LiveTrackingScreen(deliveryId: id),
              ),
            );
          },
          onPickup: () => _pickupWithQr(id),
          onSendCode: () => _markDeliveredFromSendCode(id),
        );
      },
    );
  }

  Future<void> _pickupWithQr(String deliveryId) async {
    final id = deliveryId.trim();
    if (id.isEmpty) return;

    final qrToken = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(builder: (_) => const QrScanScreen()),
    );

    if (!mounted) return;
    if (qrToken == null || qrToken.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      await apiClient.pickupDeliveryWithQr(id, qrToken: qrToken.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teslimat alındı.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teslimat alınamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markDeliveredFromSendCode(String deliveryId) async {
    final id = deliveryId.trim();
    if (id.isEmpty) return;

    try {
      await apiClient.sendDeliveryCode(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teslim kodu gönderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod gönderilemedi: $e')),
      );
    }
  }
}
