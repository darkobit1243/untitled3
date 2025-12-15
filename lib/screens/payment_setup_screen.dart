import 'package:flutter/material.dart';

import '../theme/trustship_theme.dart';

class PaymentSetupScreen extends StatefulWidget {
  const PaymentSetupScreen({super.key});

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  int _step = 0;

  String _method = 'card';
  final _cardName = TextEditingController();
  final _cardNumber = TextEditingController();
  final _iban = TextEditingController();

  @override
  void dispose() {
    _cardName.dispose();
    _cardNumber.dispose();
    _iban.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_step == 0) return true;
    if (_step == 1) {
      if (_method == 'card') {
        return _cardName.text.trim().isNotEmpty && _cardNumber.text.trim().length >= 12;
      }
      return _iban.text.trim().length >= 10;
    }
    return true;
  }

  void _next() {
    if (!_canContinue) return;
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ödeme yöntemi kaydedildi.')),
    );
    Navigator.pop(context);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme Bilgileri')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _canContinue ? _next : null,
        onStepCancel: _back,
        controlsBuilder: (context, details) {
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                style: ElevatedButton.styleFrom(backgroundColor: TrustShipColors.primaryRed),
                child: Text(_step == 2 ? 'Kaydet' : 'Devam'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: details.onStepCancel,
                child: Text(_step == 0 ? 'Kapat' : 'Geri'),
              ),
            ],
          );
        },
        steps: [
          Step(
            title: const Text('Yöntem Seç'),
            isActive: _step >= 0,
            content: Column(
              children: [
                RadioListTile<String>(
                  value: 'card',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v ?? 'card'),
                  title: const Text('Kart'),
                ),
                RadioListTile<String>(
                  value: 'bank',
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v ?? 'bank'),
                  title: const Text('Banka/IBAN'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Bilgi Gir'),
            isActive: _step >= 1,
            content: _method == 'card'
                ? Column(
                    children: [
                      TextField(
                        controller: _cardName,
                        decoration: const InputDecoration(labelText: 'Kart Üzerindeki İsim'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cardNumber,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Kart Numarası'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  )
                : TextField(
                    controller: _iban,
                    decoration: const InputDecoration(labelText: 'IBAN'),
                    onChanged: (_) => setState(() {}),
                  ),
          ),
          Step(
            title: const Text('Onayla'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seçilen yöntem: ${_method == 'card' ? 'Kart' : 'Banka/IBAN'}'),
                const SizedBox(height: 8),
                const Text(
                  'Ödeme bilgileri adım adım eklenebilir. Dilersen daha sonra güncelleyebilirsin.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
