import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_proposal_service.dart';
import '../../services/session_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cep_input_formatter.dart';
import '../../widgets/cpf_input_formatter.dart';
import '../../widgets/credit_card_payment_sheet.dart';
import '../../widgets/helpers.dart';
import '../../widgets/phone_input_formatter.dart';

/// Fluxo de pagamento em tela cheia ao aceitar uma proposta (estilo checkout).
class CheckoutPaymentScreen extends StatefulWidget {
  final ServiceRequest request;
  final ServiceProposal proposal;

  /// Reabre a tela só para ver/copiar o PIX (ou renovar se vencido).
  final bool resumePayment;

  const CheckoutPaymentScreen({
    super.key,
    required this.request,
    required this.proposal,
    this.resumePayment = false,
  });

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

enum _CheckoutStep { form, result, loading }

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _cardName = TextEditingController();
  final _cardNumber = TextEditingController();
  final _cardExpiry = TextEditingController();
  final _cardCvv = TextEditingController();
  final _postalCode = TextEditingController();
  final _addressNumber = TextEditingController();
  final _phone = TextEditingController();

  String _billingType = 'PIX';
  bool _submitting = false;
  late _CheckoutStep _step;
  ServicePayment? _payment;
  String? _resultMessage;

  ServiceProposal get proposal => widget.proposal;
  ServiceRequest get request => widget.request;

  double get _total {
    return proposal.clientAmount ?? proposal.amount;
  }

  double get _professional {
    if (proposal.professionalAmount != null) {
      return proposal.professionalAmount!;
    }
    final fee = proposal.platformFee;
    if (fee != null) return (_total - fee).clamp(0, _total);
    return (_total / 1.15);
  }

  double get _platformFee {
    return proposal.platformFee ?? (_total - _professional);
  }

  @override
  void initState() {
    super.initState();
    _step = widget.resumePayment ? _CheckoutStep.loading : _CheckoutStep.form;
    final user = SessionStore.instance.currentUser;
    _cardName.text = (user?.name ?? '').toUpperCase();
    _phone.text = PhoneInputFormatter.formatPhone(
      PhoneInputFormatter.digitsOnly(user?.phone ?? ''),
    );
    _postalCode.text = CepInputFormatter.formatCep(
      CepInputFormatter.digitsOnly(request.cep ?? ''),
    );
    _addressNumber.text = request.number ?? '';
    if (widget.resumePayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingPayment());
    }
  }

  Future<void> _loadExistingPayment({bool renew = false}) async {
    setState(() {
      _step = _CheckoutStep.loading;
      _submitting = true;
    });
    try {
      final payment = await ServiceProposalService.instance.fetchPayment(
        serviceRequestId: request.id,
        proposalId: proposal.id,
        renew: renew,
      );
      await ClientRequestsStore.instance.load();
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _billingType = payment.billingType.toUpperCase() == 'CREDIT_CARD'
            ? 'CREDIT_CARD'
            : 'PIX';
        _resultMessage = _messageForPayment(payment);
        _step = _CheckoutStep.result;
        _submitting = false;
      });
      if (renew && mounted) {
        showAppSnackBar(context, 'Novo PIX gerado.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, e.displayMessage);
      if (widget.resumePayment) {
        Navigator.pop(context, false);
      } else {
        setState(() => _step = _CheckoutStep.form);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'Não foi possível carregar o pagamento.');
      if (widget.resumePayment) {
        Navigator.pop(context, false);
      } else {
        setState(() => _step = _CheckoutStep.form);
      }
    }
  }

  @override
  void dispose() {
    _cpf.dispose();
    _cardName.dispose();
    _cardNumber.dispose();
    _cardExpiry.dispose();
    _cardCvv.dispose();
    _postalCode.dispose();
    _addressNumber.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    CreditCardFormData? creditCard;
    if (_billingType == 'CREDIT_CARD') {
      final expiryDigits = _cardExpiry.text.replaceAll(RegExp(r'\D'), '');
      if (expiryDigits.length < 4) {
        showAppSnackBar(context, 'Informe a validade no formato MM/AA');
        return;
      }
      final month = expiryDigits.substring(0, 2);
      var year = expiryDigits.substring(2);
      if (year.length == 2) year = '20$year';

      creditCard = CreditCardFormData(
        holderName: _cardName.text.trim(),
        number: _cardNumber.text.replaceAll(RegExp(r'\D'), ''),
        expiryMonth: month,
        expiryYear: year,
        ccv: _cardCvv.text.trim(),
        cpf: CpfInputFormatter.digitsOnly(_cpf.text),
        postalCode: CepInputFormatter.digitsOnly(_postalCode.text),
        addressNumber: _addressNumber.text.trim(),
        phone: PhoneInputFormatter.digitsOnly(_phone.text),
        email: SessionStore.instance.currentUser?.email,
      );
    }

    setState(() => _submitting = true);
    try {
      final updated = await ServiceProposalService.instance.updateStatus(
        serviceRequestId: request.id,
        proposalId: proposal.id,
        status: 'accepted',
        billingType: _billingType,
        cpf: CpfInputFormatter.digitsOnly(_cpf.text),
        creditCard: creditCard,
      );
      await ClientRequestsStore.instance.load();
      if (!mounted) return;

      final payment = updated.payment;

      if (payment == null) {
        showAppSnackBar(context, 'Proposta aceita.');
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _payment = payment;
        _resultMessage = _messageForPayment(payment);
        _step = _CheckoutStep.result;
        _submitting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'Não foi possível concluir o pagamento.');
    }
  }

  String _messageForPayment(ServicePayment payment) {
    final isCard = payment.billingType.toUpperCase() == 'CREDIT_CARD';
    if (payment.isPaid) {
      return 'Pagamento aprovado pelo Asaas. Serviço liberado para o profissional.';
    }
    if (isCard) {
      return 'Pagamento enviado. Aguarde a confirmação do Asaas.';
    }
    return 'Conclua o pagamento PIX. O serviço só será liberado após a aprovação do Asaas.';
  }

  Future<void> _refreshPix() async {
    await _loadExistingPayment(renew: false);
    if (!mounted) return;
    if (!(_payment?.isPaid ?? false)) {
      showAppSnackBar(
        context,
        'Ainda aguardando confirmação do Asaas.',
      );
    }
  }

  Future<void> _renewPix() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerar novo PIX'),
        content: const Text(
          'O código atual será cancelado e um novo PIX será gerado. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gerar novo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _loadExistingPayment(renew: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _step == _CheckoutStep.form
              ? 'Pagamento'
              : (_step == _CheckoutStep.loading ? 'Carregando' : 'Pagamento PIX'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting
              ? null
              : () => Navigator.pop(context, _step == _CheckoutStep.result),
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          _CheckoutStep.form => _buildForm(),
          _CheckoutStep.loading => const Center(child: CircularProgressIndicator()),
          _CheckoutStep.result => _buildResult(),
        },
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryCard(
                    requestTitle: request.title,
                    professionalName: proposal.professionalName,
                    professionalAmount: _professional,
                    platformFee: _platformFee,
                    total: _total,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Forma de pagamento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodTile(
                    selected: _billingType == 'PIX',
                    icon: Icons.qr_code_2,
                    title: 'PIX',
                    subtitle: 'Aprovação na hora após o pagamento',
                    onTap: () => setState(() => _billingType = 'PIX'),
                  ),
                  const SizedBox(height: 10),
                  _PaymentMethodTile(
                    selected: _billingType == 'CREDIT_CARD',
                    icon: Icons.credit_card,
                    title: 'Cartão de crédito',
                    subtitle: 'Pague com os dados do cartão',
                    onTap: () => setState(() => _billingType = 'CREDIT_CARD'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _cpf,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CpfInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                    ),
                    validator: CpfInputFormatter.validator,
                  ),
                  if (_billingType == 'CREDIT_CARD') ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Dados do cartão',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cardName,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nome no cartão',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o nome'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cardNumber,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_CardNumberInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Número do cartão',
                        hintText: '0000 0000 0000 0000',
                      ),
                      validator: (v) {
                        final digits =
                            (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 13) return 'Número inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cardExpiry,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_ExpiryInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Validade',
                              hintText: 'MM/AA',
                            ),
                            validator: (v) {
                              final digits =
                                  (v ?? '').replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 4) return 'Inválida';
                              final month =
                                  int.tryParse(digits.substring(0, 2)) ?? 0;
                              if (month < 1 || month > 12) {
                                return 'Mês inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cardCvv,
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
                  ],
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Total a pagar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatCurrency(_total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _billingType == 'PIX'
                            ? 'Gerar PIX'
                            : 'Pagar agora',
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final payment = _payment;
    final isCard = (payment?.billingType ?? _billingType).toUpperCase() ==
        'CREDIT_CARD';
    final isPaid = payment?.isPaid ?? false;
    final qrBytes = _decodeQr(payment?.pixQrCodeBase64);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isPaid
                            ? Icons.check_circle
                            : (isCard
                                ? Icons.hourglass_top
                                : Icons.qr_code_2),
                        size: 56,
                        color: isPaid ? AppColors.success : AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPaid
                            ? 'Pagamento confirmado'
                            : (isCard
                                ? 'Pagamento em análise'
                                : 'Pague com PIX'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _resultMessage ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        formatCurrency(payment?.totalAmount ?? _total),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCard && !isPaid) ...[
                  const SizedBox(height: 20),
                  if (qrBytes != null) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Image.memory(
                          qrBytes,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if ((payment?.pixCopyPaste ?? '').isNotEmpty) ...[
                    const Text(
                      'PIX copia e cola',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        payment!.pixCopyPaste!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: payment.pixCopyPaste!),
                        );
                        if (mounted) {
                          showAppSnackBar(context, 'Código PIX copiado');
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar código PIX'),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Não foi possível carregar o código PIX. Gere um novo.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _submitting ? null : _refreshPix,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Já paguei — atualizar status'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _renewPix,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Gerar novo PIX'),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ElevatedButton(
            onPressed: () {
              final paid = _payment?.isPaid ?? false;
              if (!paid) {
                showAppSnackBar(
                  context,
                  'Pagamento ainda pendente. O serviço só libera quando o Asaas confirmar.',
                );
              }
              Navigator.pop(context, true);
            },
            child: Text(
              (_payment?.isPaid ?? false) ? 'Concluir' : 'Fechar (pagamento pendente)',
            ),
          ),
        ),
      ],
    );
  }

  Uint8List? _decodeQr(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (value.contains(',')) {
      value = value.split(',').last;
    }
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String requestTitle;
  final String professionalName;
  final double professionalAmount;
  final double platformFee;
  final double total;

  const _SummaryCard({
    required this.requestTitle,
    required this.professionalName,
    required this.professionalAmount,
    required this.platformFee,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo do pedido',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            requestTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profissional: $professionalName',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _line('Valor do serviço', formatCurrency(professionalAmount)),
          const SizedBox(height: 8),
          _line('Taxa da plataforma', formatCurrency(platformFee)),
          const SizedBox(height: 12),
          _line(
            'Total',
            formatCurrency(total),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.border,
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
