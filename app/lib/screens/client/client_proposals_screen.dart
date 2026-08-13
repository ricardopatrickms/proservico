import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_proposal_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';

class ClientProposalsScreen extends StatefulWidget {
  /// Se informado, foca nesta solicitação; senão lista todas com propostas.
  final ServiceRequest? request;

  const ClientProposalsScreen({super.key, this.request});

  @override
  State<ClientProposalsScreen> createState() => _ClientProposalsScreenState();
}

class _ClientProposalsScreenState extends State<ClientProposalsScreen> {
  final _store = ClientRequestsStore.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    _store.load();
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<ServiceRequest> get _items {
    final all = _store.requests.where((r) => r.proposals.isNotEmpty).toList();
    if (widget.request == null) return all;
    final match = all.where((r) => r.id == widget.request!.id).toList();
    if (match.isNotEmpty) return match;
    // Ainda pode ter propostas no objeto passado (antes do reload).
    return widget.request!.proposals.isEmpty ? const [] : [widget.request!];
  }

  String _shortDate(DateTime date) =>
      DateFormat('dd/MM/yyyy', 'pt_BR').format(date);

  String _dateTime(DateTime date) =>
      DateFormat("dd/MM/yyyy 'às' HH:mm:ss", 'pt_BR').format(date);

  Future<void> _respond({
    required ServiceRequest request,
    required ServiceProposal proposal,
    required String status,
  }) async {
    final accepting = status == 'accepted';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accepting ? 'Aceitar proposta' : 'Recusar proposta'),
        content: Text(
          accepting
              ? 'Aceitar a proposta de ${proposal.professionalName} por ${formatCurrency(proposal.amount)}?'
              : 'Recusar a proposta de ${proposal.professionalName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accepting ? 'Aceitar' : 'Recusar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ServiceProposalService.instance.updateStatus(
        serviceRequestId: request.id,
        proposalId: proposal.id,
        status: status,
      );
      await _store.load();
      if (!mounted) return;
      showAppSnackBar(
        context,
        accepting ? 'Proposta aceita.' : 'Proposta recusada.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível atualizar a proposta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Propostas Recebidas'),
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _store.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text(
                  'Propostas Recebidas',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Analise e responda às propostas dos profissionais',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_store.loading && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Nenhuma proposta recebida ainda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...items.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _RequestProposalsCard(
                        request: request,
                        requestedAt: _shortDate(
                          request.createdAt ?? request.scheduledAt,
                        ),
                        formatDateTime: _dateTime,
                        onAccept: (p) => _respond(
                          request: request,
                          proposal: p,
                          status: 'accepted',
                        ),
                        onReject: (p) => _respond(
                          request: request,
                          proposal: p,
                          status: 'rejected',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _RequestProposalsCard extends StatelessWidget {
  final ServiceRequest request;
  final String requestedAt;
  final String Function(DateTime) formatDateTime;
  final ValueChanged<ServiceProposal> onAccept;
  final ValueChanged<ServiceProposal> onReject;

  const _RequestProposalsCard({
    required this.request,
    required this.requestedAt,
    required this.formatDateTime,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final proposals = request.proposals;
    final pending = proposals
        .where((p) => p.status == ProposalStatus.pending)
        .length;

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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(
                label: '${proposals.length} proposta(s)',
                background: const Color(0xFFF3F4F6),
                foreground: AppColors.textSecondary,
              ),
              if (pending > 0)
                _Pill(
                  label: '$pending aguardando resposta',
                  background: const Color(0xFFFFF7ED),
                  foreground: AppColors.warning,
                ),
            ],
          ),
          if (request.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Solicitado em $requestedAt',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Propostas Recebidas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...proposals.map(
            (proposal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProposalCard(
                proposal: proposal,
                sentAt: formatDateTime(proposal.createdAt),
                onAccept: proposal.status == ProposalStatus.pending
                    ? () => onAccept(proposal)
                    : null,
                onReject: proposal.status == ProposalStatus.pending
                    ? () => onReject(proposal)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final ServiceProposal proposal;
  final String sentAt;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _ProposalCard({
    required this.proposal,
    required this.sentAt,
    this.onAccept,
    this.onReject,
  });

  Color get _statusBg {
    return switch (proposal.status) {
      ProposalStatus.pending => const Color(0xFFDBEAFE),
      ProposalStatus.accepted => const Color(0xFFDCFCE7),
      ProposalStatus.rejected => const Color(0xFFFEE2E2),
      ProposalStatus.withdrawn => const Color(0xFFF3F4F6),
    };
  }

  Color get _statusFg {
    return switch (proposal.status) {
      ProposalStatus.pending => AppColors.primaryDark,
      ProposalStatus.accepted => AppColors.success,
      ProposalStatus.rejected => AppColors.danger,
      ProposalStatus.withdrawn => AppColors.textSecondary,
    };
  }

  String get _statusLabel {
    return switch (proposal.status) {
      ProposalStatus.pending => 'Aguardando',
      ProposalStatus.accepted => 'Aceita',
      ProposalStatus.rejected => 'Recusada',
      ProposalStatus.withdrawn => 'Retirada',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
                    _Pill(
                      label: _statusLabel,
                      background: _statusBg,
                      foreground: _statusFg,
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(proposal.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Avaliação: Sem avaliações ainda',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              proposal.message,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enviada em $sentAt',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (onAccept != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onAccept != null)
                  Expanded(
                    child: Material(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: onAccept,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Aceitar e Pagar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (onAccept != null && onReject != null) const SizedBox(width: 8),
                if (onReject != null)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onReject,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, size: 16, color: AppColors.danger),
                              SizedBox(width: 6),
                              Text(
                                'Recusar',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({
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
