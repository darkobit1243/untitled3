import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/bitasi_theme.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_section_card.dart';
import '../widgets/common/app_text_field.dart';

class OfferAmountScreen extends StatefulWidget {
  const OfferAmountScreen({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<OfferAmountScreen> createState() => _OfferAmountScreenState();
}

class _OfferAmountScreenState extends State<OfferAmountScreen> {
  late final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final raw = _controller.text.trim();
    final normalized = raw.replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // TODO: hook real API call if/when needed.
      if (!mounted) return;
      Navigator.of(context).pop(normalized);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teklif Ver'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _submitting ? null : _close,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              AppSectionCard(
                child: AppTextField(
                  label: 'Teklif Tutarı (TL)',
                  controller: _controller,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  prefixIcon: Icons.payments_outlined,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outlined(
                      label: 'İptal',
                      onPressed: _submitting ? null : _close,
                      fullWidth: true,
                      height: 50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        elevatedButtonTheme: ElevatedButtonThemeData(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BiTasiColors.primaryRed,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      child: AppButton.primary(
                        label: 'Gönder',
                        onPressed: _submitting ? null : _submit,
                        isLoading: _submitting,
                        fullWidth: true,
                        height: 50,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
