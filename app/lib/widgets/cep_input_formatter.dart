import 'package:flutter/services.dart';

/// Máscara de CEP BR: `00000-000`.
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = formatCep(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatCep(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 5) return digits;
    return '${digits.substring(0, 5)}-${digits.substring(5)}';
  }

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');
}
