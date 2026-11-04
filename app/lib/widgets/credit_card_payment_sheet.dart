import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'cep_input_formatter.dart';
import 'cpf_input_formatter.dart';
import 'helpers.dart';
import 'phone_input_formatter.dart';

class CreditCardFormData {
  final String holderName;
  final String number;
  final String expiryMonth;
  final String expiryYear;
  final String ccv;
  final String cpf;
  final String? postalCode;
  final String? addressNumber;
  final String? phone;
  final String? email;

  const CreditCardFormData({
    required this.holderName,
    required this.number,
    required this.expiryMonth,
    required this.expiryYear,
    required this.ccv,
    required this.cpf,
    this.postalCode,
    this.addressNumber,
    this.phone,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'holder_name': holderName,
        'number': number,
        'expiry_month': expiryMonth,
        'expiry_year': expiryYear,
        'ccv': ccv,
        'cpf': cpf,
        if (postalCode != null && postalCode!.isNotEmpty) 'postal_code': postalCode,
        if (addressNumber != null && addressNumber!.isNotEmpty)
          'address_number': addressNumber,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
      };
}

Future<CreditCardFormData?> showCreditCardPaymentSheet({
  required BuildContext context,
  required double totalAmount,
  String? initialName,
  String? initialEmail,
  String? initialCpf,
  String? initialPhone,
  String? initialPostalCode,
  String? initialAddressNumber,
}) {
  return showModalBottomSheet<CreditCardFormData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _CreditCardPaymentSheet(
        totalAmount: totalAmount,
        initialName: initialName,
        initialEmail: initialEmail,
        initialCpf: initialCpf,
        initialPhone: initialPhone,
        initialPostalCode: initialPostalCode,
        initialAddressNumber: initialAddressNumber,
      ),
    ),
  );
}

class _CreditCardPaymentSheet extends StatefulWidget {
  final double totalAmount;
  final String? initialName;
  final String? initialEmail;
  final String? initialCpf;
  final String? initialPhone;
  final String? initialPostalCode;
  final String? initialAddressNumber;

  const _CreditCardPaymentSheet({
    required this.totalAmount,
    this.initialName,
    this.initialEmail,
    this.initialCpf,
    this.initialPhone,
    this.initialPostalCode,
    this.initialAddressNumber,
  });

  @override
  State<_CreditCardPaymentSheet> createState() =>
      _CreditCardPaymentSheetState();
}

class _CreditCardPaymentSheetState extends State<_CreditCardPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _number;
  late final TextEditingController _expiry;
  late final TextEditingController _ccv;
  late final TextEditingController _cpf;
  late final TextEditingController _postalCode;
  late final TextEditingController _addressNumber;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _number = TextEditingController();
    _expiry = TextEditingController();
    _ccv = TextEditingController();
    _cpf = TextEditingController(
      text: CpfInputFormatter.formatCpf(
        CpfInputFormatter.digitsOnly(widget.initialCpf ?? ''),
      ),
    );
    _postalCode = TextEditingController(
      text: CepInputFormatter.formatCep(
        CepInputFormatter.digitsOnly(widget.initialPostalCode ?? ''),
      ),
    );
    _addressNumber =
        TextEditingController(text: widget.initialAddressNumber ?? '');
    _phone = TextEditingController(
      text: PhoneInputFormatter.formatPhone(
        PhoneInputFormatter.digitsOnly(widget.initialPhone ?? ''),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _expiry.dispose();
    _ccv.dispose();
    _cpf.dispose();
    _postalCode.dispose();
    _addressNumber.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final expiryDigits = _expiry.text.replaceAll(RegExp(r'\D'), '');
    if (expiryDigits.length < 4) {
      showAppSnackBar(context, 'Informe a validade no formato MM/AA');
      return;
    }

    final month = expiryDigits.substring(0, 2);
    var year = expiryDigits.substring(2);
    if (year.length == 2) year = '20$year';

    Navigator.pop(
      context,
      CreditCardFormData(
        holderName: _name.text.trim(),
        number: _number.text.replaceAll(RegExp(r'\D'), ''),
        expiryMonth: month,
        expiryYear: year,
        ccv: _ccv.text.trim(),
        cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''),
        postalCode: _postalCode.text.replaceAll(RegExp(r'\D'), ''),
        addressNumber: _addressNumber.text.trim(),
        phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
        email: widget.initialEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pagamento no cartão',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${formatCurrency(widget.totalAmount)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Nome no cartão',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _number,
                keyboardType: TextInputType.number,
                inputFormatters: [_CardNumberInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Número do cartão',
                  hintText: '0000 0000 0000 0000',
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 13) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiry,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_ExpiryInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Validade',
                        hintText: 'MM/AA',
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 4) return 'Inválida';
                        final month = int.tryParse(digits.substring(0, 2)) ?? 0;
                        if (month < 1 || month > 12) return 'Mês inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ccv,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '000',
                      ),
                      validator: (v) {
                        if (v == null || v.length < 3) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cpf,
                keyboardType: TextInputType.number,
                inputFormatters: [CpfInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'CPF do titular',
                  hintText: '000.000.000-00',
                ),
                validator: CpfInputFormatter.validator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _postalCode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CepInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'CEP',
                        hintText: '00000-000',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _addressNumber,
                      decoration: const InputDecoration(
                        labelText: 'Nº',
                        hintText: '123',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  hintText: '(00) 00000-0000',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Pagar agora'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
