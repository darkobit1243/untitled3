import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

String buildRandomTrPhoneHint({Random? random}) {
  // 10 hane TR GSM: 5xxxxxxxxx
  final rnd = random ?? Random();
  final digits = StringBuffer('5');
  for (var i = 0; i < 9; i++) {
    digits.write(rnd.nextInt(10));
  }
  final raw = digits.toString();
  return '${raw.substring(0, 3)}-${raw.substring(3, 6)}-${raw.substring(6)}';
}

String? normalizeTrPhoneToE164(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // TR için kullanıcı genelde "544-567-5582" gibi girer.
  // Tire/boşluk/parantez vs. temizle, sadece rakamları al.
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  // Kabul edilen girişler:
  // - 10 hane: 5xxxxxxxxx  -> +90
  // - 11 hane: 05xxxxxxxxx -> +90
  // - 12 hane: 90 + 10 hane -> +90
  // - E.164 girilmişse (+90...) zaten digits=90...
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 12 && digits.startsWith('90')) {
    digits = digits.substring(2);
  }

  // TR GSM numarası 10 hane ve 5 ile başlar.
  if (digits.length != 10 || !digits.startsWith('5')) {
    return null;
  }

  return '+90$digits';
}

String friendlyFirebaseAuthError(FirebaseAuthException e) {
  // Common Firebase Phone Auth errors.
  switch (e.code) {
    case 'billing-not-enabled':
      return 'SMS doğrulama için Firebase projesinde faturalandırma (Blaze) gerekir.\n\nSadece test amaçlıysa: Firebase Console > Authentication > Sign-in method > Phone > Test phone numbers kısmından test numarası ekleyip onunla deneyin.';
    case 'quota-exceeded':
      return 'SMS kotası aşıldı. Bir süre bekleyip tekrar deneyin.\n\nTest için: Firebase Console > Authentication > Phone > Test phone numbers.';
    case 'invalid-phone-number':
      return 'Telefon numarası geçersiz. 10 haneli 5xxxxxxxxx formatında gir.';
    case 'too-many-requests':
      return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
    case 'captcha-check-failed':
    case 'invalid-app-credential':
    case 'app-not-authorized':
    case 'missing-client-identifier':
      return 'Uygulama doğrulanamadı (Play Integrity / reCAPTCHA).\n\nÇözüm: Firebase Console > Project settings > Android app (com.example.untitled) içine SHA-1 ve SHA-256 ekle, sonra yeni google-services.json indirip projeye koy. Google Cloud’da Play Integrity API açık olsun.\n\nDetay: ${e.code}: ${e.message ?? ''}'.trim();
    default:
      final msg = (e.message ?? '').trim();
      if (msg.isEmpty) return 'SMS doğrulama başlatılamadı. (${e.code})';
      return '${e.code}: $msg';
  }
}
