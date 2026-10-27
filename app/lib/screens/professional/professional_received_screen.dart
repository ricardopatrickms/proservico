import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/session_store.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import 'professional_placeholder_screen.dart';
import 'professional_request_detail_sheet.dart';
import 'send_proposal_sheet.dart';

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
  final Set<String> _sentProposalIds = {};
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

  bool _hasSentProposal(ServiceRequest request) {
    final userId = SessionStore.instance.currentUser?.id;
    if (userId != null &&
        request.proposals.any((p) => p.professionalId == userId)) {
      return true;
    }
    return _sentProposalIds.contains(request.id);
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final all = await _service.list();
      if (!mounted) return;
      final pending = all
          .where((r) => r.status == ServiceStatus.pending)
          .toList();
      final userId = SessionStore.instance.currentUser?.id;
      setState(() {
        _requests = pending;
        if (userId != null) {
          for (final request in pending) {
            if (request.proposals.any((p) => p.professionalId == userId)) {
              _sentProposalIds.add(request.id);
            }
          }
        }
        _loading = false;
        _error = null;
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
      subtitle: 'Novos pedidos de clientes na sua cidade',
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
                    'Só aparecem pedidos da mesma cidade do seu cadastro. Confira seu endereço no perfil.',
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
                    proposalSent: _hasSentProposal(request),
                    onDetails: () => _openDetails(request),
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
    if (_hasSentProposal(request)) return;
    final sent = await sendProposal(context, request);
    if (sent) await _onProposalSent(request);
  }

  Future<void> _openDetails(ServiceRequest request) async {
    final sent = await showProfessionalRequestDetail(
      context,
      request,
      canSendProposal: !_hasSentProposal(request),
    );
    if (sent == true) await _onProposalSent(request);
  }

  Future<void> _onProposalSent(ServiceRequest request) async {
    if (!mounted) return;
    setState(() => _sentProposalIds.add(request.id));
    await _load(showSpinner: false);
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
  final bool proposalSent;
  final VoidCallback onDetails;
  final VoidCallback onPropose;

  const _ReceivedCard({
    required this.request,
    required this.createdLabel,
    required this.scheduledLabel,
    required this.proposalSent,
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
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 420;
              final propose = Material(
                color: proposalSent ? AppColors.success : AppColors.navy,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: proposalSent ? null : onPropose,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (proposalSent) ...[
                            const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            proposalSent
                                ? 'Proposta Enviada'
                                : 'Enviar Proposta',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
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