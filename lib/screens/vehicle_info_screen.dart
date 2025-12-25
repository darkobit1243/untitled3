import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/bitasi_theme.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({
    super.key,
    required this.initialProfile,
  });

  final Map<String, dynamic> initialProfile;

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _vehicleType;
  late final TextEditingController _vehiclePlate;
  late final TextEditingController _serviceArea;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vehicleType = TextEditingController(text: widget.initialProfile['vehicleType']?.toString() ?? '');
    _vehiclePlate = TextEditingController(text: widget.initialProfile['vehiclePlate']?.toString() ?? '');
    _serviceArea = TextEditingController(text: widget.initialProfile['serviceArea']?.toString() ?? '');
  }

  @override
  void dispose() {
    _vehicleType.dispose();
    _vehiclePlate.dispose();
    _serviceArea.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final updated = await apiClient.updateMyProfile(profile: {
        'vehicleType': _vehicleType.text.trim(),
        'vehiclePlate': _vehiclePlate.text.trim(),
        'serviceArea': _serviceArea.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pop<Map<String, dynamic>>(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Araç bilgileri kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Bilgileri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _vehicleType,
                  decoration: const InputDecoration(labelText: 'Araç tipi'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehiclePlate,
                  decoration: const InputDecoration(labelText: 'Plaka'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serviceArea,
                  decoration: const InputDecoration(labelText: 'Servis bölgesi'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: BiTasiColors.primaryRed),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kaydet'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bu bilgiler taşıyıcı profilinde görünür.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
