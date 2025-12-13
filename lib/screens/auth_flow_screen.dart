// lib/screens/auth_flow_screen.dart
//
// Çok adımlı kayıt akışı:
// 1) Rol seçimi (gönderici / taşıyıcı)
// 2) Seçilen role göre basit kayıt formu
// Kayıttan sonra otomatik login yapıp MainWrapper'a yönlendirir.

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/trustship_theme.dart';
import 'main_wrapper.dart';

enum AuthView {
  roleSelection,
  senderRegistration,
  carrierRegistration,
}

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  AuthView _currentView = AuthView.roleSelection;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _senderAddressController = TextEditingController();
  final _carrierVehicleTypeController = TextEditingController();
  final _carrierVehiclePlateController = TextEditingController();
  final _carrierServiceAreaController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _senderAddressController.dispose();
    _carrierVehicleTypeController.dispose();
    _carrierVehiclePlateController.dispose();
    _carrierServiceAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case AuthView.roleSelection:
        return _buildRoleSelection();
      case AuthView.senderRegistration:
        return _buildRegistrationForm(role: 'sender');
      case AuthView.carrierRegistration:
        return _buildRegistrationForm(role: 'carrier');
    }
  }

  Widget _buildRoleSelection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nasıl kullanmak istiyorsun?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gönderici olarak kargo çıkabilir veya taşıyıcı olarak yolculuklarında ek gelir elde edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _roleCard(
              icon: Icons.send_outlined,
              title: 'Gönderici',
              description: 'Paketlerini farklı şehirlere güvenle gönder.',
              color: TrustShipColors.primaryRed,
              onTap: () {
                setState(() {
                  _currentView = AuthView.senderRegistration;
                });
              },
            ),
            const SizedBox(height: 16),
            _roleCard(
              icon: Icons.directions_car,
              title: 'Taşıyıcı',
              description: 'Yolculuklarını kazanca çevir, kargo taşı.',
              color: TrustShipColors.successGreen,
              onTap: () {
                setState(() {
                  _currentView = AuthView.carrierRegistration;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm({required String role}) {
    final isSender = role == 'sender';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentView = AuthView.roleSelection;
                    _error = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                label: const Text('Geri'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSender ? 'Gönderici Kaydı' : 'Taşıyıcı Kaydı',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSender
                    ? 'Paket göndermek için hızlıca bir hesap oluştur.'
                    : 'Yolculuklarında kargo taşıyıp gelir elde etmek için kayıt ol.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const Text(
                'E-posta Adresi',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'ornek@eposta.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() {
                      _error = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Şifre',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'En az 6 karakter',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Şifre (Tekrar)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordConfirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Şifreni tekrar gir',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              _buildCommonFields(),
              const SizedBox(height: 16),
              isSender ? _buildSenderFields() : _buildCarrierFields(),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrustShipColors.primaryRed,
                  ),
                  onPressed: _isLoading ? null : () => _handleRegister(role),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Kayıt Ol',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommonFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tam İsim',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            hintText: 'Tam adınız',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Telefon',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+90 5xx xxx xx xx',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildSenderFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gönderi Bölgesi / Adres',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _senderAddressController,
          decoration: const InputDecoration(
            hintText: 'Şehir, semt veya özel adres',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildCarrierFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Araç Tipi',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _carrierVehicleTypeController,
          decoration: const InputDecoration(
            hintText: 'Otomobil, panelvan, kamyonet vb.',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Araç Plakası',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _carrierVehiclePlateController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: '34ABC34',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Servis Bölgesi',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _carrierServiceAreaController,
          decoration: const InputDecoration(
            hintText: 'Çalıştığınız şehir / gece rotası',
            prefixIcon: Icon(Icons.public),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister(String role) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        _error = 'Lütfen tüm alanları doldur.';
      });
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _error = 'Lütfen geçerli bir e-posta gir.';
      });
      return;
    }
    if (fullName.isEmpty || phone.isEmpty) {
      setState(() {
        _error = 'İsim ve telefon bilgilerini gir.';
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Şifre en az 6 karakter olmalıdır.';
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _error = 'Şifreler eşleşmiyor.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1) Backend'de kullanıcıyı oluştur
      final profile = <String, dynamic>{
        'fullName': fullName,
        'phone': phone,
      };
      if (role == 'sender') {
        final address = _senderAddressController.text.trim();
        if (address.isEmpty) {
          setState(() {
            _error = 'Gönderim yapan olarak adres bilgisi gereklidir.';
          });
          return;
        }
        profile['address'] = address;
      } else {
        final vehicleType = _carrierVehicleTypeController.text.trim();
        final vehiclePlate = _carrierVehiclePlateController.text.trim();
        final serviceArea = _carrierServiceAreaController.text.trim();
        if (vehicleType.isEmpty || vehiclePlate.isEmpty) {
          setState(() {
            _error = 'Araç tipi ve plaka giriniz.';
          });
          return;
        }
        profile['vehicleType'] = vehicleType;
        profile['vehiclePlate'] = vehiclePlate;
        if (serviceArea.isNotEmpty) {
          profile['serviceArea'] = serviceArea;
        }
      }

      await apiClient.register(email, password, role: role, profile: profile);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kayıt başarısız: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}


