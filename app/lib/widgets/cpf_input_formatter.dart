import 'package:flutter/services.dart';

/// Máscara de CPF: `000.000.000-00`.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = formatCpf(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatCpf(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}.${digits.substring(3)}';
    }
    if (digits.length <= 9) {
      return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
    }
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Validação oficial do CPF (dígitos verificadores + rejeita sequências iguais).
  static bool isValid(String value) {
    final cpf = digitsOnly(value);
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    final numbers = cpf.split('').map(int.parse).toList();

    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += numbers[i] * (10 - i);
    }
    var firstDigit = (sum * 10) % 11;
    if (firstDigit == 10) firstDigit = 0;
    if (firstDigit != numbers[9]) return false;

    sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += numbers[i] * (11 - i);
    }
    var secondDigit = (sum * 10) % 11;
    if (secondDigit == 10) secondDigit = 0;
    return secondDigit == numbers[10];
  }

  static String? validator(String? value) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) return 'Informe o CPF';
    if (digits.length != 11) return 'Informe um CPF válido com 11 dígitos';
    if (!isValid(digits)) return 'CPF inválido';
    return null;
  }
}
