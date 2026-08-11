import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/mock_store.dart';
import '../../models/service_request.dart';
import '../../models/user.dart';
import '../../services/api_exception.dart';
import '../../services/service_proposal_service.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import 'professional_placeholder_screen.dart';
import 'professional_request_detail_sheet.dart';

class ProfessionalReceivedScreen extends StatefulWidget {
  const ProfessionalReceivedScreen({super.key});

  @override
  State<ProfessionalReceivedScreen> createState() =>
      _ProfessionalReceivedScreenState();
}

class _ProfessionalReceivedScreenState
    extends State<ProfessionalReceivedScreen> {
  final _service = ServiceRequestService.instance;
  final _searchController = TextEditingController();

  List<ServiceRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _service.list();
      if (!mounted) return;
      setState(() {
        // Pedidos disponíveis: pendentes (ainda sem profissional).
        _requests = all
            .where((r) => r.status == ServiceStatus.pending)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.displayMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as solicitações.';
        _loading = false;
      });
    }
  }

  List<ServiceRequest> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _requests;
    return _requests.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q) ||
          (r.category?.toLowerCase().contains(q) ?? false) ||
          (r.city?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  int get _urgentCount => _filtered
      .where(
        (r) =>
            r.urgency == ServiceUrgency.urgent ||
            r.urgency == ServiceUrgency.emergency,
      )
      .length;

  String _shortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
  }

  String _dateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return ProfessionalPageScaffold(
      title: 'Solicitações de Serviços',
      subtitle: 'Novos pedidos de clientes em sua área de atuação',
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar solicitações...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Disponível',
                    value: '${filtered.length}',
                    icon: Icons.search,
                    iconBackground: const Color(0xFFEFF6FF),
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Urgentes',
                    value: '$_urgentCount',
                    icon: Icons.access_time,
                    iconBackground: const Color(0xFFFFF7ED),
                    iconColor: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _EmptyCard(
                icon: Icons.error_outline,
                title: _error!,
                subtitle: 'Puxe para atualizar ou tente novamente.',
                action: TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              )
            else if (filtered.isEmpty)
              const _EmptyCard(
                icon: Icons.search,
                title: 'Nenhuma solicitação encontrada',
                subtitle:
                    'Não há solicitações de serviços disponíveis no momento para sua área de atuação.',
              )
            else
              ...filtered.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReceivedCard(
                    request: request,
                    createdLabel: _dateTime(
                      request.createdAt ?? request.scheduledAt,
                    ),
                    scheduledLabel: _shortDate(request.scheduledAt),
                    onDetails: () => showProfessionalRequestDetail(context, request),
                    onPropose: () => _openProposeSheet(request),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProposeSheet(ServiceRequest request) async {
    final user = MockStore.instance.currentUser;
    if (user == null || user.type != AccountType.professional) {
      showAppSnackBar(
        context,
        'É preciso estar logado como profissional para enviar propostas.',
      );
      return;
    }

    final result = await showModalBottomSheet<_ProposeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProposeBottomSheet(request: request),
    );
    if (!mounted || result == null) return;

    try {
      await ServiceProposalService.instance.create(
        serviceRequestId: request.id,
        amount: result.value,
        message: result.message,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Proposta de ${formatCurrency(result.value)} enviada.',
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível enviar a proposta.');
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.border.withValues(alpha: 0.9)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class _ReceivedCard extends StatelessWidget {
  final ServiceRequest request;
  final String createdLabel;
  final String scheduledLabel;
  final VoidCallback onDetails;
  final VoidCallback onPropose;

  const _ReceivedCard({
    required this.request,
    required this.createdLabel,
    required this.scheduledLabel,
    required this.onDetails,
    required this.onPropose,
  });

  (String, Color, Color) get _urgencyStyle {
    return switch (request.urgency) {
      ServiceUrgency.urgent => (
          'Urgente',
          const Color(0xFFFEE2E2),
          AppColors.danger,
        ),
      ServiceUrgency.emergency => (
          'Emergência',
          const Color(0xFFFEE2E2),
          AppColors.danger,
        ),
      ServiceUrgency.normal => (
          'Normal',
          const Color(0xFFF3F4F6),
          AppColors.textSecondary,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final urgency = _urgencyStyle;
    final budget = request.budgetRangeLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (request.category != null && request.category!.isNotEmpty) ...[
                _Chip(
                  label: request.category!,
                  background: const Color(0xFFEFF6FF),
                  foreground: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
              ],
              _Chip(
                label: urgency.$1,
                background: urgency.$2,
                foreground: urgency.$3,
              ),
              const Spacer(),
              Text(
                createdLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (request.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Meta(
                icon: Icons.place_outlined,
                text: request.cityStateLabel,
              ),
              _Meta(
                icon: Icons.calendar_today_outlined,
                text: scheduledLabel,
              ),
              if (budget != null)
                _Meta(
                  icon: Icons.attach_money,
                  text: budget,
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 420;
              final propose = Material(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onPropose,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Center(
                      child: Text(
                        'Enviar Proposta',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final details = Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDetails,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Ver Detalhes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    propose,
                    const SizedBox(height: 10),
                    details,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: propose),
                  const SizedBox(width: 10),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProposeResult {
  final double value;
  final String message;

  const _ProposeResult({required this.value, required this.message});
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
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _valueController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final raw = _valueController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null) return;

    setState(() => _submitting = true);
    Navigator.of(context).pop(
      _ProposeResult(
        value: value,
        message: _messageController.text.trim(),
      ),
    );
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
                  if (request.budgetRangeLabel != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Faixa de preço do cliente',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.attach_money,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  request.budgetRangeLabel!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (request.budgetMin != null ||
                              request.budgetMax != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (request.budgetMin != null)
                                  Expanded(
                                    child: Text(
                                      'Mín: ${formatCurrency(request.budgetMin!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                if (request.budgetMax != null)
                                  Expanded(
                                    child: Text(
                                      'Máx: ${formatCurrency(request.budgetMax!)}',
                                      textAlign: request.budgetMin != null
                                          ? TextAlign.end
                                          : TextAlign.start,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (request.acceptsNegotiation) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Cliente aberto a negociação',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                  const SizedBox(height: 16),
                  const Text(
                    'Mensagem para o cliente *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText:
                          'Descreva sua proposta, prazo e condições...',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return 'Escreva uma mensagem com pelo menos 10 caracteres';
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
