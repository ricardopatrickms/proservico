import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../professional/professional_request_detail_sheet.dart';
import 'client_proposals_screen.dart';

class ClientServicesScreen extends StatefulWidget {
  const ClientServicesScreen({super.key});

  @override
  State<ClientServicesScreen> createState() => _ClientServicesScreenState();
}

class _ClientServicesScreenState extends State<ClientServicesScreen>
    with AutomaticKeepAliveClientMixin {
  final _store = ClientRequestsStore.instance;
  int _tab = 0; // 0 = ativos, 1 = histórico

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  List<ServiceRequest> get _active => _store.requests
      .where(
        (r) =>
            r.status == ServiceStatus.pending ||
            r.status == ServiceStatus.inProgress,
      )
      .toList();

  List<ServiceRequest> get _history => _store.requests
      .where(
        (r) =>
            r.status == ServiceStatus.completed ||
            r.status == ServiceStatus.cancelled,
      )
      .toList();

  String _shortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
  }

  Future<void> _cancelRequest(ServiceRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar serviço'),
        content: const Text('Deseja cancelar esta solicitação?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ServiceRequestService.instance.updateStatus(
        request.id,
        status: 'cancelled',
      );
      await _store.load();
      if (!mounted) return;
      showAppSnackBar(context, 'Solicitação cancelada.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível cancelar.');
    }
  }

  void _openAllProposalsModal(ServiceRequest request) {
    showDialog<void>(
      context: context,
      builder: (context) => _ServiceProposalsDialog(request: request),
    );
  }

  void _openProposalsPage(ServiceRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientProposalsScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shown = _tab == 0 ? _active : _history;
    final total = _store.requests.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _store.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Meus Serviços',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gerencie seus serviços ativos e consulte o histórico',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total de serviços encontrados: $total',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _SegmentedTabs(
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 16),
              if (_store.loading && _store.requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shown.isEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _tab == 0
                        ? 'Nenhum serviço ativo no momento'
                        : 'Nenhum serviço no histórico',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                ...shown.map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ClientServiceCard(
                      request: request,
                      requestedAtLabel: _shortDate(
                        request.createdAt ?? request.scheduledAt,
                      ),
                      isHistory: _tab == 1,
                      onDetails: () =>
                          showProfessionalRequestDetail(context, request),
                      onCancel: () => _cancelRequest(request),
                      onEdit: () {
                        showAppSnackBar(
                          context,
                          'Edição de solicitação em breve.',
                        );
                      },
                      onViewProposals: () => _openAllProposalsModal(request),
                      onGoToProposals: () => _openProposalsPage(request),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientServiceCard extends StatelessWidget {
  final ServiceRequest request;
  final String requestedAtLabel;
  final bool isHistory;
  final VoidCallback onDetails;
  final VoidCallback onCancel;
  final VoidCallback onEdit;
  final VoidCallback onViewProposals;
  final VoidCallback onGoToProposals;

  const _ClientServiceCard({
    required this.request,
    required this.requestedAtLabel,
    required this.isHistory,
    required this.onDetails,
    required this.onCancel,
    required this.onEdit,
    required this.onViewProposals,
    required this.onGoToProposals,
  });

  @override
  Widget build(BuildContext context) {
    final proposals = request.proposals;
    final hasProposals = proposals.isNotEmpty;
    final preview = hasProposals ? proposals.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                label: hasProposals
                    ? '${proposals.length} Proposta(s) Recebida(s)'
                    : 'Aguardando',
                background: hasProposals
                    ? AppColors.primary
                    : AppColors.warning,
                foreground: hasProposals ? Colors.white : Colors.white,
              ),
              Text(
                'Solicitado em $requestedAtLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (request.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Descrição: ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: request.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Propostas Recebidas:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _ProposalPreview(proposal: preview),
          ],
          if (!isHistory) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OutlineAction(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  color: AppColors.primary,
                  onTap: onEdit,
                ),
                _OutlineAction(
                  label: 'Cancelar',
                  icon: Icons.close,
                  color: AppColors.danger,
                  onTap: onCancel,
                ),
                if (hasProposals)
                  _OutlineAction(
                    label: 'Ver Todas as Propostas (${proposals.length})',
                    icon: Icons.visibility_outlined,
                    color: AppColors.primary,
                    onTap: onViewProposals,
                  ),
                if (hasProposals)
                  _OutlineAction(
                    label: 'Ir para Propostas',
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.success,
                    onTap: onGoToProposals,
                  ),
                if (!hasProposals)
                  _OutlineAction(
                    label: 'Ver detalhes',
                    icon: Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    borderColor: AppColors.border,
                    onTap: onDetails,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProposalPreview extends StatelessWidget {
  final ServiceProposal proposal;

  const _ProposalPreview({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final when = DateFormat("dd/MM/yyyy 'às' HH:mm:ss", 'pt_BR')
        .format(proposal.createdAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${proposal.professionalName}  ·  ${proposal.statusLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(proposal.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  const Text(
                    'Valor final para o cliente',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              proposal.message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enviada em $when',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusPill({
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? borderColor;
  final VoidCallback onTap;

  const _OutlineAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor ?? color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceProposalsDialog extends StatelessWidget {
  final ServiceRequest request;

  const _ServiceProposalsDialog({required this.request});

  Color _statusBg(ProposalStatus status) {
    return switch (status) {
      ProposalStatus.pending => const Color(0xFFDBEAFE),
      ProposalStatus.accepted => const Color(0xFFDCFCE7),
      ProposalStatus.rejected => const Color(0xFFE5E7EB),
      ProposalStatus.withdrawn => const Color(0xFFF3F4F6),
    };
  }

  Color _statusFg(ProposalStatus status) {
    return switch (status) {
      ProposalStatus.pending => AppColors.primaryDark,
      ProposalStatus.accepted => AppColors.success,
      ProposalStatus.rejected => AppColors.textSecondary,
      ProposalStatus.withdrawn => AppColors.textSecondary,
    };
  }

  String _statusLabel(ProposalStatus status) {
    return switch (status) {
      ProposalStatus.pending => 'Aguardando',
      ProposalStatus.accepted => 'Aceita',
      ProposalStatus.rejected => 'Recusada',
      ProposalStatus.withdrawn => 'Retirada',
    };
  }

  @override
  Widget build(BuildContext context) {
    final proposals = request.proposals;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Propostas',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: proposals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final proposal = proposals[index];
                  final when = DateFormat("dd/MM/yyyy 'às' HH:mm:ss", 'pt_BR')
                      .format(proposal.createdAt);

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.person_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    proposal.professionalName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusBg(proposal.status),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusLabel(proposal.status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _statusFg(proposal.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatCurrency(proposal.amount),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Mensagem do profissional:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            proposal.message,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Enviada em $when',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Serviços Ativos',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabPill(
              label: 'Histórico',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
