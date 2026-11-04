import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/service_request.dart';
import '../theme/app_theme.dart';
import 'helpers.dart';

Future<void> showPixPaymentSheet({
  required BuildContext context,
  required ServicePayment payment,
}) {
  return showPaymentSheet(context: context, payment: payment);
}

Future<void> showPaymentSheet({
  required BuildContext context,
  required ServicePayment payment,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PaymentSheet(payment: payment),
  );
}

class _PaymentSheet extends StatelessWidget {
  final ServicePayment payment;

  const _PaymentSheet({required this.payment});

  bool get _isPaid => payment.isPaid;

  @override
  Widget build(BuildContext context) {
    final qrBytes = _decodeQr(payment.pixQrCodeBase64);
    final isCard = payment.billingType.toUpperCase() == 'CREDIT_CARD';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
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
            Text(
              _isPaid
                  ? 'Pagamento confirmado'
                  : (isCard ? 'Pagamento no cartão' : 'Pagamento PIX'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${formatCurrency(payment.totalAmount)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            if (_isPaid)
              const Text(
                'O serviço já foi liberado para o profissional.',
                style: TextStyle(fontSize: 14, height: 1.4),
              )
            else if (!isCard) ...[
              if (qrBytes != null) ...[
                Center(
                  child: Image.memory(
                    qrBytes,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if ((payment.pixCopyPaste ?? '').isNotEmpty) ...[
                const Text(
                  'PIX copia e cola',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  payment.pixCopyPaste!,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: payment.pixCopyPaste!),
                    );
                    if (context.mounted) {
                      showAppSnackBar(context, 'Código PIX copiado');
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código PIX'),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Após o pagamento, o serviço será liberado automaticamente.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ] else
              const Text(
                'Aguarde a confirmação do pagamento.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
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
