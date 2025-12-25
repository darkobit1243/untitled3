import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/bitasi_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  // Users tab state
  List<dynamic> _users = [];
  bool _isLoadingUsers = false;
  String _filterStatus = 'pending'; // pending, verified, banned, active, all
  String _filterRole = 'carrier'; // carrier, sender, all

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
    _loadUsers();
  }

  Future<void> _loadStats() async {
    try {
      final data = await apiClient.fetchAdminStats();
      if (!mounted) return;
      setState(() {
        _stats = data;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İstatistik hatası: $e')));
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final role = _filterRole == 'all' ? null : _filterRole;
      final status = _filterStatus == 'all' ? null : _filterStatus;
      
      final result = await apiClient.fetchAdminUsers(role: role, status: status);
      if (!mounted) return;
      setState(() {
        _users = result['data'] ?? [];
        _isLoadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kullanıcı hatası: $e')));
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _verifyUser(String userId, bool approve) async {
    try {
      await apiClient.adminVerifyUser(userId, approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Kullanıcı onaylandı.' : 'Kullanıcı reddedildi.')),
      );
      _loadUsers();
      _loadStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  Future<void> _banUser(String userId, bool ban) async {
    try {
      await apiClient.adminSetBanStatus(userId, ban);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ban ? 'Kullanıcı yasaklandı.' : 'Kullanıcı yasağı kalktı.')),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: BiTasiColors.primaryRed,
          unselectedLabelColor: Colors.grey,
          indicatorColor: BiTasiColors.primaryRed,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Kullanıcı Yönetimi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildUsersTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoadingStats) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return const Center(child: Text('Veri yok'));

    final users = _stats!['users'] ?? {};
    final listings = _stats!['listings'] ?? {};
    final deliveries = _stats!['deliveries'] ?? {};

    return RefreshIndicator(
      onRefresh: () async {
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard('Toplam Kullanıcı', '${users['total'] ?? 0}', Icons.people, Colors.blue),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Kuryeler', '${users['carriers'] ?? 0}', Icons.local_shipping, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Göndericiler', '${users['senders'] ?? 0}', Icons.person, Colors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard('Bekleyen Onaylar', '${users['pending'] ?? 0}', Icons.warning_amber, Colors.redAccent),
          const SizedBox(height: 24),
          const Text('Platform Özeti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Toplam İlan', '${listings['total'] ?? 0}', Icons.list_alt, Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Teslimatlar', '${deliveries['total'] ?? 0}', Icons.check_circle, Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Onay Bekleyenler', 'pending', isStatus: true),
                    const SizedBox(width: 8),
                    _buildFilterChip('Tüm Kuryeler', 'active', isStatus: true), // active status generic name
                    const SizedBox(width: 8),
                    _buildFilterChip('Yasaklılar', 'banned', isStatus: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Role Toggle
              Row(
                children: [
                   const Text('Rol: ', style: TextStyle(fontWeight: FontWeight.bold)),
                   DropdownButton<String>(
                     value: _filterRole,
                     items: const [
                       DropdownMenuItem(value: 'all', child: Text('Hepsi')),
                       DropdownMenuItem(value: 'carrier', child: Text('Kurye')),
                       DropdownMenuItem(value: 'sender', child: Text('Gönderici')),
                     ],
                     onChanged: (v) {
                       if (v != null) {
                         setState(() => _filterRole = v);
                         _loadUsers();
                       }
                     },
                   )
                ],
              )
            ],
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('Kullanıcı bulunamadı.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) => _buildUserRow(_users[idx]),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isStatus = false}) {
    final selected = isStatus ? _filterStatus == value : _filterRole == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            if (isStatus) {
              _filterStatus = value;
            } else {
              _filterRole = value;
            }
          });
          _loadUsers();
        }
      },
      selectedColor: BiTasiColors.primaryRed.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: selected ? BiTasiColors.primaryRed : Colors.black),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final isVerified = user['isVerified'] == true;
    final isActive = user['isActive'] == true;
    final role = user['role'] ?? 'user';
    final email = user['email'] ?? '';
    final name = user['fullName'] ?? 'İsimsiz';
    final userId = user['id'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(name.substring(0, 1).toUpperCase())),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name ($role)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (!isActive)
                 const Chip(label: Text('BANLI'), backgroundColor: Colors.red, labelStyle: TextStyle(color: Colors.white, fontSize: 10)),
              if (isActive && !isVerified && role == 'carrier')
                  const Chip(label: Text('ONAYSIZ'), backgroundColor: Colors.orange, labelStyle: TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (role == 'carrier' && !isVerified && isActive)
                TextButton(
                  onPressed: () => _verifyUser(userId, true),
                  child: const Text('ONAYLA', style: TextStyle(color: Colors.green)),
                ),
              
              if (isActive)
                TextButton(
                  onPressed: () => _banUser(userId, true),
                  child: const Text('YASAKLA', style: TextStyle(color: Colors.red)),
                )
              else
                 TextButton(
                  onPressed: () => _banUser(userId, false),
                  child: const Text('YASAĞI KALDIR', style: TextStyle(color: Colors.blue)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
