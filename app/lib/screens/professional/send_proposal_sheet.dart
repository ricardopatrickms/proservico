import 'package:flutter/material.dart';

import '../../models/service_request.dart';
import '../../models/user.dart';
import '../../services/api_exception.dart';
import '../../services/service_proposal_service.dart';
import '../../services/session_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';

/// Abre o formulário de proposta e envia para a API.
/// Retorna `true` quando a proposta foi enviada com sucesso.
Future<bool> sendProposal(BuildContext context, ServiceRequest request) async {
  final user = SessionStore.instance.currentUser;
  if (user == null || user.type != AccountType.professional) {
    showAppSnackBar(
      context,
      'É preciso estar logado como profissional para enviar propostas.',
    );
    return false;
  }

  final value = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProposeBottomSheet(request: request),
  );
  if (!context.mounted || value == null) return false;

  try {
    await ServiceProposalService.instance.create(
      serviceRequestId: request.id,
      amount: value,
    );
    if (!context.mounted) return true;
    showAppSnackBar(context, 'Proposta de ${formatCurrency(value)} enviada.');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showAppSnackBar(context, e.displayMessage);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'Não foi possível enviar a proposta.');
    }
  }
  return false;
}

class _ProposeBottomSheet extends StatefulWidget {
  final ServiceRequest request;

  const _ProposeBottomSheet({required this.request});

  @override
  State<_ProposeBottomSheet> createState() => _ProposeBottomSheetState();
}

class _ProposeBottomSheetState extends State<_ProposeBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final raw = _valueController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null) return;

    setState(() => _submitting = true);
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final request = widget.request;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Form(
              key: _formKey,
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
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enviar Proposta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Valor Proposto (R\$) *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ex: 150,00',
                      prefixText: 'R\$ ',
                    ),
                    validator: (v) {
                      final raw = (v ?? '')
                          .trim()
                          .replaceAll('.', '')
                          .replaceAll(',', '.');
                      final value = double.tryParse(raw);
                      if (value == null || value <= 0) {
                        return 'Informe um valor válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _submitting ? null : _submit,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            _submitting ? 'Enviando...' : 'Enviar Proposta',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
