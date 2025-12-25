import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../utils/common/signed_url_cache.dart';
import '../../widgets/sender/offers/offer_card.dart';
import '../../widgets/sender/offers/offer_empty_state.dart';
import '../../widgets/sender/offers/offer_list_header.dart';
import '../../widgets/sender/offers/offer_profile_sheet.dart';

class TeklifListesiSheet extends StatefulWidget {
  const TeklifListesiSheet({
    super.key,
    required this.listingId,
    required this.title,
  });

  final String listingId;
  final String title;

  @override
  State<TeklifListesiSheet> createState() => _TeklifListesiSheetState();
}

class _TeklifListesiSheetState extends State<TeklifListesiSheet> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 20;
  int? _serverTotal;
  List<Map<String, dynamic>> _offers = [];
  late final ScrollController _scrollController;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= max - 240) {
      // ignore: unawaited_futures
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _serverTotal = null;
        _offers = [];
      }
    });

    try {
      final res = await apiClient.fetchOffersForListingPaged(
        widget.listingId,
        page: _page,
        limit: _limit,
      );

      final dataRaw = res['data'];
      final meta = (res['meta'] is Map) ? (res['meta'] as Map) : null;
      final total = meta?['total'];
      final lastPage = meta?['lastPage'];
      final pageNum = meta?['page'];

      final data = (dataRaw is List)
          ? dataRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _offers = data;
        _serverTotal = total is num ? total.toInt() : _serverTotal;
        final resolvedLastPage = lastPage is num ? lastPage.toInt() : 1;
        final resolvedPage = pageNum is num ? pageNum.toInt() : 1;
        _hasMore = resolvedPage < resolvedLastPage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklifler alınamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final nextPage = _page + 1;
      final res = await apiClient.fetchOffersForListingPaged(
        widget.listingId,
        page: nextPage,
        limit: _limit,
      );

      final dataRaw = res['data'];
      final meta = (res['meta'] is Map) ? (res['meta'] as Map) : null;
      final total = meta?['total'];
      final lastPage = meta?['lastPage'];
      final pageNum = meta?['page'];

      final newItems = (dataRaw is List)
          ? dataRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _page = nextPage;
        _offers = [..._offers, ...newItems];
        _serverTotal = total is num ? total.toInt() : _serverTotal;
        final resolvedLastPage = lastPage is num ? lastPage.toInt() : nextPage;
        final resolvedPage = pageNum is num ? pageNum.toInt() : nextPage;
        _hasMore = resolvedPage < resolvedLastPage;
      });
    } catch (_) {
      // ignore load-more errors
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _handleAccept(String offerId) async {
    final previous = _offers.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() => _actionLoading = true);
    try {
      setState(() {
        _offers = _offers
            .map((o) => {
                  ...o,
                  'status': (o['id']?.toString() == offerId) ? 'accepted' : 'rejected',
                })
            .toList();
      });
      await apiClient.acceptOffer(offerId);
      // ignore: unawaited_futures
      _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teklif kabul edildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _offers = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kabul edilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _handleReject(String offerId) async {
    final previous = _offers.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() => _actionLoading = true);
    try {
      setState(() {
        _offers = _offers
            .map((o) => o['id']?.toString() == offerId ? {...o, 'status': 'rejected'} : o)
            .toList();
      });
      await apiClient.rejectOffer(offerId);
      // ignore: unawaited_futures
      _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teklif reddedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _offers = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reddedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.65, // biraz daha ferah yarım ekran
      child: Builder(
        builder: (context) {
          final totalCount = _serverTotal ?? _offers.length;
          if (_loading && _offers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_loading && _offers.isEmpty) {
            return const OfferEmptyState();
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfferListHeader(
                  title: 'Teklifler',
                  subtitle: widget.title,
                  countLabel: _serverTotal != null ? '${_offers.length}/$totalCount' : '$totalCount',
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                if (_actionLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (_actionLoading) const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: _offers.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index >= _offers.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                        );
                      }

                      final offer = _offers[index];
                      final amount = offer['amount']?.toString() ?? '-';
                      final status = offer['status']?.toString() ?? 'pending';
                      final userLabel = offer['proposerName']?.toString() ??
                          offer['proposerId']?.toString() ??
                          'Taşıyıcı';
                      final avatarKey = offer['proposerAvatarKey']?.toString();
                      final avatar = signedUrlCache.resolve(
                        key: avatarKey,
                        signedUrl: offer['proposerAvatar']?.toString(),
                      );
                      final rating = (offer['proposerRating'] as num?)?.toDouble();
                      final delivered = (offer['proposerDelivered'] as num?)?.toInt();
                      final proposerId = offer['proposerId']?.toString();
                      final createdAt = offer['createdAt']?.toString() ?? '';
                      final offerId = offer['id']?.toString() ?? '';

                      return OfferCard(
                        amountLabel: '$amount TL',
                        status: status,
                        userLabel: userLabel,
                        avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
                        rating: rating,
                        delivered: delivered,
                        createdAtLabel: createdAt,
                        actionLoading: _actionLoading,
                        onReject: () => _handleReject(offerId),
                        onAccept: () => _handleAccept(offerId),
                        onViewProfile: proposerId == null
                            ? null
                            : () async {
                                try {
                                  final data = await apiClient.fetchUserById(proposerId);
                                  if (context.mounted) {
                                    _showProfileSheet(context, data);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Profil alınamadı: $e')),
                                    );
                                  }
                                }
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProfileSheet(BuildContext context, Map<String, dynamic> data) {
    final avatarUrl = signedUrlCache.resolve(
      key: data['avatarKey']?.toString(),
      signedUrl: data['avatarUrl']?.toString(),
    );
    final name = data['fullName']?.toString() ?? data['email']?.toString() ?? 'Kullanıcı';
    final role = data['role']?.toString();
    final rating = (data['rating'] as num?)?.toDouble();
    final delivered = (data['deliveredCount'] as num?)?.toInt();
    final isVerified = data['isVerified'] == true;
    final isActive = data['isActive'] != false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => OfferProfileSheet(
        avatarUrl: avatarUrl,
        name: name,
        role: role,
        rating: rating,
        delivered: delivered,
        isVerified: isVerified,
        isActive: isActive,
        phone: data['phone']?.toString(),
        address: data['address']?.toString(),
      ),
    );
  }
}