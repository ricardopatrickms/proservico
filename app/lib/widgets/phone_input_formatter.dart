import 'package:flutter/services.dart';

/// Máscara de telefone BR: `(XX) XXXX-XXXX` ou `(XX) XXXXX-XXXX`.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = formatPhone(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatPhone(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 2) return '($digits';
    if (digits.length <= 6) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    }
    if (digits.length <= 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
  }

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');
}
