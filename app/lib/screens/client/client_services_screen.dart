import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../../widgets/service_cards.dart';
import '../professional/professional_request_detail_sheet.dart';
import 'client_proposals_screen.dart';

class ClientServicesScreen extends StatefulWidget {
  final ValueChanged<ServiceRequest>? onOpenProposals;

  const ClientServicesScreen({super.key, this.onOpenProposals});

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
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  List<ServiceRequest> get _active => _store.requests
      .where(
        (r) =>
            r.status == ServiceStatus.pending ||
            r.status == ServiceStatus.inProgress,
      )
      .toList();

  List<ServiceRequest> get _history {
    final items = [..._store.requests];
    items.sort((a, b) {
      final aDate = a.createdAt ?? a.scheduledAt;
      final bDate = b.createdAt ?? b.scheduledAt;
      return bDate.compareTo(aDate);
    });
    return items;
  }

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
    final open = widget.onOpenProposals;
    if (open != null) {
      open(request);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientProposalsScreen(request: request),
      ),
    );
  }

  Future<void> _openEditSheet(ServiceRequest request) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditServiceSheet(request: request),
    );
    if (updated == true && mounted) {
      showAppSnackBar(context, 'Serviço atualizado.');
    }
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
                      onEdit: () => _openEditSheet(request),
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
              if (isHistory)
                StatusBadge(status: request.status)
              else
                _StatusPill(
                  label: hasProposals
                      ? '${proposals.length} Proposta(s) Recebida(s)'
                      : 'Aguardando',
                  background:
                      hasProposals ? AppColors.primary : AppColors.warning,
                  foreground: Colors.white,
                ),
              if (isHistory && hasProposals)
                _StatusPill(
                  label: '${proposals.length} Proposta(s) Recebida(s)',
                  background: AppColors.primary,
                  foreground: Colors.white,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isHistory) ...[
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
              ],
              if (hasProposals) ...[
                _OutlineAction(
                  label: 'Ver Todas as Propostas (${proposals.length})',
                  icon: Icons.visibility_outlined,
                  color: AppColors.primary,
                  onTap: onViewProposals,
                ),
                if (!isHistory)
                  _OutlineAction(
                    label: 'Ir para Propostas',
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.success,
                    onTap: onGoToProposals,
                  ),
              ],
              if (isHistory || !hasProposals)
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

class _EditServiceSheet extends StatefulWidget {
  final ServiceRequest request;

  const _EditServiceSheet({required this.request});

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _cepController;
  late final TextEditingController _descriptionController;
  late final List<String> _categoryOptions;
  String? _category;
  bool _saving = false;

  static const _categories = [
    'Elétrica',
    'Hidráulica',
    'Climatização',
    'Pintura',
    'Limpeza',
    'Jardinagem',
    'Marcenaria',
    'Alvenaria',
    'Informática',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    final hasStructuredAddress = request.address?.trim().isNotEmpty == true ||
        request.city?.trim().isNotEmpty == true;

    _addressController = TextEditingController(
      text: request.address?.trim().isNotEmpty == true
          ? request.address!.trim()
          : (hasStructuredAddress ? '' : request.location),
    );
    _cityController = TextEditingController(text: request.city?.trim() ?? '');
    _stateController = TextEditingController(text: request.state?.trim() ?? '');
    _cepController = TextEditingController(text: request.cep?.trim() ?? '');
    _descriptionController = TextEditingController(
      text: request.description,
    );

    final rawCategory = (request.category ?? '').trim();
    final matched = _categories.cast<String?>().firstWhere(
          (c) => c!.toLowerCase() == rawCategory.toLowerCase(),
          orElse: () => null,
        );
    if (matched != null) {
      _category = matched;
      _categoryOptions = List<String>.from(_categories);
    } else if (rawCategory.isNotEmpty) {
      _category = rawCategory;
      _categoryOptions = [rawCategory, ..._categories];
    } else {
      final titleMatch = _categories.cast<String?>().firstWhere(
            (c) => c!.toLowerCase() == request.title.trim().toLowerCase(),
            orElse: () => null,
          );
      _category = titleMatch;
      _categoryOptions = List<String>.from(_categories);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _cepController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final category = _category;
    if (category == null || category.isEmpty) {
      showAppSnackBar(context, 'Selecione o tipo de serviço');
      return;
    }

    setState(() => _saving = true);
    try {
      await ClientRequestsStore.instance.update(
        widget.request.id,
        category: category,
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim().toUpperCase(),
        cep: _cepController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível salvar as alterações.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Editar Serviço',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _fieldLabel('Endereço completo'),
                  TextFormField(
                    controller: _addressController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Rua, número e bairro',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o endereço'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Cidade'),
                  TextFormField(
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Cidade',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe a cidade'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Estado'),
                            TextFormField(
                              controller: _stateController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              maxLength: 2,
                              decoration: const InputDecoration(
                                hintText: 'UF',
                                counterText: '',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length != 2)
                                      ? 'UF inválida'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('CEP'),
                            TextFormField(
                              controller: _cepController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: '00000-000',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 8)
                                      ? 'CEP inválido'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Tipo de Serviço'),
                  DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Selecione o tipo',
                    ),
                    items: _categoryOptions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _category = v),
                    validator: (v) =>
                        v == null ? 'Selecione o tipo de serviço' : null,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Descrição do problema'),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 8,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Descreva o problema ou o serviço desejado',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe a descrição'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salvar Alterações'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
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
