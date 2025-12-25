import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';
import '../../utils/common/signed_url_cache.dart';

class OffersForListingSheet extends StatefulWidget {
  const OffersForListingSheet({
    super.key,
    required this.listingId,
    required this.title,
  });

  final String listingId;
  final String title;

  @override
  State<OffersForListingSheet> createState() => _OffersForListingSheetState();
}

class _OffersForListingSheetState extends State<OffersForListingSheet> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 20;
  int? _serverTotal;
  late final ScrollController _scrollController;
  bool _actionLoading = false;
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _filteredOffers = [];
  bool _filtersDirty = true;
  String _sort = 'amount_asc';
  String _statusFilter = 'all';

  Widget _buildEmptyOffers() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: BiTasiColors.primaryBlue.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                color: BiTasiColors.primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Henüz teklif yok',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu ilana yeni bir teklif gelince burada göreceksin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelect({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(child: child),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final offerId = offer['id']?.toString() ?? '';
    final amount = offer['amount']?.toString() ?? '-';
    final status = offer['status']?.toString() ?? 'pending';
    final proposerName = offer['proposerName']?.toString() ?? offer['proposerId']?.toString() ?? 'Taşıyıcı';
    final proposerAvatarKey = offer['proposerAvatarKey']?.toString();
    final proposerAvatar = signedUrlCache.resolve(
      key: proposerAvatarKey,
      signedUrl: offer['proposerAvatar']?.toString(),
    );

    final isPending = status == 'pending';

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: BiTasiColors.primaryBlue.withAlpha(28),
                backgroundImage: proposerAvatar != null && proposerAvatar.isNotEmpty ? NetworkImage(proposerAvatar) : null,
                child: (proposerAvatar == null || proposerAvatar.isEmpty)
                    ? const Icon(Icons.local_shipping_outlined, color: BiTasiColors.primaryBlue)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$amount TL',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      proposerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPending && offerId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionLoading ? null : () => _updateOffer(offerId, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BiTasiColors.errorRed,
                      side: const BorderSide(color: BiTasiColors.errorRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : () => _updateOffer(offerId, true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Kabul Et'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BiTasiColors.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters() {
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(_offers);
    if (_statusFilter != 'all') {
      list = list.where((o) => (o['status']?.toString() ?? '') == _statusFilter).toList();
    }
    list.sort((a, b) {
      final aa = (a['amount'] is num) ? (a['amount'] as num).toDouble() : (double.tryParse(a['amount']?.toString() ?? '') ?? 0);
      final bb = (b['amount'] is num) ? (b['amount'] as num).toDouble() : (double.tryParse(b['amount']?.toString() ?? '') ?? 0);
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
        _filteredOffers = [];
        _filtersDirty = false;
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
        _filtersDirty = true;
        _serverTotal = total is num ? total.toInt() : _serverTotal;
        final resolvedLastPage = lastPage is num ? lastPage.toInt() : 1;
        final resolvedPage = pageNum is num ? pageNum.toInt() : 1;
        _hasMore = resolvedPage < resolvedLastPage;
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
        _filtersDirty = true;
        _serverTotal = total is num ? total.toInt() : _serverTotal;
        final resolvedLastPage = lastPage is num ? lastPage.toInt() : nextPage;
        final resolvedPage = pageNum is num ? pageNum.toInt() : nextPage;
        _hasMore = resolvedPage < resolvedLastPage;
      });
    } catch (_) {
      // Ignore load-more errors; user can retry by scrolling.
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filtersDirty) {
      _filteredOffers = _applyFilters();
      _filtersDirty = false;
    }
    final filtered = _filteredOffers;

    final totalCount = _serverTotal ?? _offers.length;
    final filteredCount = filtered.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Teklifler',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BiTasiColors.primaryBlue.withAlpha(16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusFilter == 'all'
                        ? (_serverTotal != null ? '${_offers.length}/$totalCount' : '$totalCount')
                        : '$filteredCount/$totalCount',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: BiTasiColors.primaryBlue),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (!_loading && _offers.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSelect(
                      label: 'Sırala',
                      child: DropdownButton<String>(
                        value: _sort,
                        items: const [
                          DropdownMenuItem(value: 'amount_asc', child: Text('Artan fiyat')),
                          DropdownMenuItem(value: 'amount_desc', child: Text('Azalan fiyat')),
                          DropdownMenuItem(value: 'date_desc', child: Text('En yeni')),
                          DropdownMenuItem(value: 'date_asc', child: Text('En eski')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _sort = v;
                            _filtersDirty = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildSelect(
                      label: 'Durum',
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tümü')),
                          DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                          DropdownMenuItem(value: 'accepted', child: Text('Kabul')),
                          DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _statusFilter = v;
                            _filtersDirty = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (_actionLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (filtered.isEmpty)
              _buildEmptyOffers()
            else
              Flexible(
                child: ListView.separated(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: filtered.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index >= filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    final offer = filtered[index];
                    return _buildOfferCard(offer);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOffer(String offerId, bool accept) async {
    final previous = _offers.map((e) => Map<String, dynamic>.from(e)).toList();
    try {
      setState(() {
        _actionLoading = true;
        if (accept) {
          _offers = _offers
              .map((o) => {
                    ...o,
                    'status': (o['id']?.toString() == offerId) ? 'accepted' : 'rejected',
                  })
              .toList();
        } else {
          _offers = _offers
              .map((o) => o['id']?.toString() == offerId ? {...o, 'status': 'rejected'} : o)
              .toList();
        }
        _filtersDirty = true;
      });
      if (accept) {
        await apiClient.acceptOffer(offerId);
      } else {
        await apiClient.rejectOffer(offerId);
      }
      // Refresh first page in background to sync server truth without flicker.
      // ignore: unawaited_futures
      _load(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Teklif kabul edildi.' : 'Teklif reddedildi.'),
        ),
      );
    } catch (_) {
      // Revert UI on failure.
      if (mounted) {
        setState(() {
          _offers = previous;
          _filtersDirty = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarısız, tekrar dene.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }
}
