import 'package:flutter/services.dart';

/// Máscara de moeda BR: `1.234,56` (centavos implícitos).
class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter({this.maxDigits = 11});

  /// Limite de dígitos (incluindo centavos). 11 → até 999.999.999,99
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited =
        digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final formatted = formatFromDigits(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatFromDigits(String digits) {
    if (digits.isEmpty) return '';

    final padded = digits.padLeft(3, '0');
    final cents = padded.substring(padded.length - 2);
    var reais = padded.substring(0, padded.length - 2).replaceFirst(RegExp(r'^0+'), '');
    if (reais.isEmpty) reais = '0';

    final withThousands = _addThousands(reais);
    return '$withThousands,$cents';
  }

  static String _addThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  /// Converte texto mascarado (`1.234,56`) em `double`.
  static double? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed
        .replaceAll(RegExp(r'[^\d,.]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }
}
