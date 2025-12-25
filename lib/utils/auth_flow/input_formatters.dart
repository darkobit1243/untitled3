import 'package:flutter/services.dart';

class TrNameFormatter extends TextInputFormatter {
  const TrNameFormatter();

  String _upperTr(String s) {
    if (s.isEmpty) return s;
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  String _lowerTr(String s) {
    if (s.isEmpty) return s;
    return s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  }

  String _toNameCase(String input) {
    final endsWithSpace = input.isNotEmpty && RegExp(r'\s$').hasMatch(input);
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trimLeft();
    if (normalized.isEmpty) return '';

    final parts = normalized.split(' ');
    final cased = parts
        .map((p) {
          final word = p.trim();
          if (word.isEmpty) return '';
          if (word.length == 1) return _upperTr(word);
          final first = _upperTr(word[0]);
          final rest = _lowerTr(word.substring(1));
          return '$first$rest';
        })
        .where((p) => p.isNotEmpty);
    final result = cased.join(' ');

    // Kullanıcı ikinci isme geçmek için boşluk yazdığında, formatter boşluğu anında
    // silmesin; tek bir trailing boşluğu koru.
    if (endsWithSpace && result.isNotEmpty) {
      return '$result ';
    }
    return result;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = _toNameCase(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Turkish phone input formatter that auto-inserts hyphens in 3-3-4 format.
///
/// User types digits only; formatter displays like: 544-567-5582.
class TrPhoneHyphenFormatter extends TextInputFormatter {
  const TrPhoneHyphenFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    // TR GSM numbers should start with 5 (e.g., 5xxxxxxxxx). If user starts with
    // something else, force it to 5.
    if (digits.isNotEmpty && digits[0] != '5') {
      digits = digits.length == 1 ? '5' : '5${digits.substring(1)}';
    }

    final formatted = _format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
  }
}
