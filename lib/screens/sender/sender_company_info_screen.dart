import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/app_settings.dart';
import '../../services/local_notifications.dart';
import '../../services/push_config.dart';
import '../../services/push_notifications.dart';
import '../../services/tr_location_assets.dart';
import '../../theme/app_ui.dart';
import '../../theme/bitasi_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_text_field.dart';
import '../main_wrapper.dart';
import 'sender_welcome_loading_screen.dart';

class SenderCompanyInfoScreen extends StatefulWidget {
  const SenderCompanyInfoScreen({
    super.key,
    required this.firebaseIdToken,
    required this.email,
    required this.password,
    required this.profile,
  });

  final String firebaseIdToken;
  final String? email;
  final String password;
  final Map<String, dynamic> profile;

  @override
  State<SenderCompanyInfoScreen> createState() => _SenderCompanyInfoScreenState();
}

class _SenderCompanyInfoScreenState extends State<SenderCompanyInfoScreen> {
  final _companyNameController = TextEditingController();
  final _taxNumberController = TextEditingController();

  final _scrollController = ScrollController();
  final _kCompanyName = GlobalKey();
  final _kTaxNumber = GlobalKey();
  final _kCity = GlobalKey();
  final _kDistrict = GlobalKey();
  final _kActivity = GlobalKey();
  final _kAvatar = GlobalKey();

  final _companyNameFocus = FocusNode();
  final _taxNumberFocus = FocusNode();

  String? _activityArea;
  XFile? _pickedAvatar;

  List<TrCity> _cities = const [];
  List<TrDistrict> _districts = const [];
  String? _selectedCityId;
  String? _selectedDistrictId;
  bool _isLoadingLocations = false;

  bool _isSubmitting = false;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  static const List<String> _activityOptions = <String>[
    'E-ticaret',
    'Gıda',
    'Tekstil',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      final data = await TrLocationAssets.load();
      if (!mounted) return;
      setState(() {
        _cities = data.cities;
        _districts = data.districts;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error ??= 'İl/ilçe verileri yüklenemedi. assets/data/il.json ve assets/data/ilce.json dosyalarını kontrol et.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxNumberController.dispose();
    _scrollController.dispose();
    _companyNameFocus.dispose();
    _taxNumberFocus.dispose();
    super.dispose();
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  String _inferMimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<String> _buildPickedAvatarDataUrl() async {
    final picked = _pickedAvatar;
    if (picked == null) {
      throw StateError('picked avatar is null');
    }
    final bytes = await File(picked.path).readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = _inferMimeTypeFromPath(picked.path);
    return 'data:$mime;base64,$b64';
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (image == null) return;
      setState(() {
        _pickedAvatar = image;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Galeri açılamadı, izinleri kontrol et.')),
      );
    }
  }

  Future<void> _finishRegistration() async {
    final companyName = _companyNameController.text.trim();
    final taxNumber = _taxNumberController.text.trim();
    final selectedCityId = _selectedCityId;
    final selectedDistrictId = _selectedDistrictId;

    if (_isLoadingLocations) {
      setState(() {
        _error = 'İl/ilçe verileri yükleniyor, lütfen bekle.';
      });
      await _scrollToKey(_kCity);
      return;
    }

    if (companyName.isEmpty || taxNumber.isEmpty || _activityArea == null) {
      setState(() {
        _error = 'Lütfen firma bilgilerini eksiksiz doldur.';
      });

      if (companyName.isEmpty) {
        await _scrollToKey(_kCompanyName);
      } else if (taxNumber.isEmpty) {
        await _scrollToKey(_kTaxNumber);
      } else {
        await _scrollToKey(_kActivity);
      }
      return;
    }

    if (selectedCityId == null || selectedDistrictId == null) {
      setState(() {
        _error = 'Lütfen il ve ilçe seç.';
      });
      await _scrollToKey(selectedCityId == null ? _kCity : _kDistrict);
      return;
    }

    if (_pickedAvatar == null) {
      setState(() {
        _error = 'Lütfen profil fotoğrafı ekle.';
      });
      await _scrollToKey(_kAvatar);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final avatarDataUrl = await _buildPickedAvatarDataUrl();

      String? cityName;
      for (final c in _cities) {
        if (c.id == selectedCityId) {
          cityName = c.name;
          break;
        }
      }
      String? districtName;
      for (final d in _districts) {
        if (d.id == selectedDistrictId) {
          districtName = d.name;
          break;
        }
      }

      final profile = <String, dynamic>{
        ...widget.profile,
        'companyName': companyName,
        'taxNumber': taxNumber,
        'cityId': selectedCityId,
        'districtId': selectedDistrictId,
        'city': cityName,
        'district': districtName,
        // Backward-compatible field name (backend currently expects taxOffice string).
        'taxOffice': '${cityName ?? ''}/${districtName ?? ''}'.trim(),
        'activityArea': _activityArea,
        // Backend'de avatarUrl string olarak saklanıyor. Şimdilik data-url göndereceğiz.
        'avatarUrl': avatarDataUrl,
      };

      await apiClient.registerWithFirebaseIdToken(
        widget.firebaseIdToken,
        role: 'sender',
        email: widget.email,
        password: widget.password,
        profile: profile,
      );

      if (!mounted) return;
      final nav = Navigator.of(context);
      final fullName = (profile['fullName']?.toString().trim().isNotEmpty ?? false)
          ? profile['fullName'].toString().trim()
          : 'Kullanıcı';

      // Side effects (push setup + welcome notification) should not block navigation.
      // ignore: unawaited_futures
      (() async {
        if (kEnableFirebasePush) {
          await pushNotifications.syncWithSettings();
        }

        try {
          final enabled = await appSettings.getNotificationsEnabled();
          if (enabled) {
            await localNotifications.showWelcome(fullName: fullName);
          }
        } catch (_) {
          // Ignore.
        }
      })();

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainWrapper()),
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.push(
          PageRouteBuilder(
            opaque: false,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (_, __, ___) => SenderWelcomeLoadingScreen(
              fullName: fullName,
              companyName: companyName,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kayıt tamamlanamadı: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma Bilgileri'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kayıt işlemini tamamlamak için firma bilgilerini ve profil fotoğrafını ekle.',
                  style: AppText.helper,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BiTasiColors.errorRed.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: const TextStyle(color: BiTasiColors.errorRed)),
                  ),
                  const SizedBox(height: 16),
                ],
                AppSectionCard(
                  child: Center(
                    child: Semantics(
                      key: _kAvatar,
                      button: true,
                      label: 'Profil fotoğrafı seç',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _isSubmitting ? null : _pickAvatarFromGallery,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: BiTasiColors.backgroundGrey,
                          backgroundImage: _pickedAvatar == null ? null : FileImage(File(_pickedAvatar!.path)),
                          child: _pickedAvatar == null
                              ? const Icon(Icons.camera_alt_outlined, color: BiTasiColors.primaryRed, size: 28)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        key: _kCompanyName,
                        child: AppTextField(
                          label: 'Firma Adı',
                          controller: _companyNameController,
                          hintText: 'Örn: BiTaşı Lojistik',
                          prefixIcon: Icons.business_outlined,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.next,
                          focusNode: _companyNameFocus,
                          nextFocusNode: _taxNumberFocus,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Container(
                        key: _kTaxNumber,
                        child: AppTextField(
                          label: 'Vergi Numarası',
                          controller: _taxNumberController,
                          hintText: 'Örn: 1234567890',
                          prefixIcon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.done,
                          focusNode: _taxNumberFocus,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Container(
                        key: _kCity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('İl', style: AppText.label),
                            const SizedBox(height: AppSpace.xs),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_selectedCityId),
                              initialValue: _selectedCityId,
                              items: _cities
                                  .map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
                                  .toList(growable: false),
                              onChanged: (_isSubmitting || _isLoadingLocations)
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _selectedCityId = v;
                                        _selectedDistrictId = null;
                                      });
                                    },
                              decoration: const InputDecoration(
                                hintText: 'Seçiniz',
                                prefixIcon: Icon(Icons.map_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Container(
                        key: _kDistrict,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('İlçe', style: AppText.label),
                            const SizedBox(height: AppSpace.xs),
                            DropdownButtonFormField<String>(
                              key: ValueKey('${_selectedCityId ?? ''}-${_selectedDistrictId ?? ''}'),
                              initialValue: _selectedDistrictId,
                              items: _districts
                                  .where((d) => d.cityId == _selectedCityId)
                                  .map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.name)))
                                  .toList(growable: false),
                              onChanged: (_isSubmitting || _isLoadingLocations || _selectedCityId == null)
                                  ? null
                                  : (v) => setState(() => _selectedDistrictId = v),
                              decoration: const InputDecoration(
                                hintText: 'Seçiniz',
                                prefixIcon: Icon(Icons.location_city_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Container(
                        key: _kActivity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Faaliyet Alanı', style: AppText.label),
                            const SizedBox(height: AppSpace.xs),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_activityArea),
                              initialValue: _activityArea,
                              items: _activityOptions
                                  .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
                                  .toList(growable: false),
                              onChanged: _isSubmitting ? null : (v) => setState(() => _activityArea = v),
                              decoration: const InputDecoration(
                                hintText: 'Seçiniz',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      AppButton.primary(
                        label: 'Kaydı Tamamla',
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _finishRegistration,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
