import 'package:flutter/material.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../client/service_detail_screen.dart';
import 'professional_placeholder_screen.dart';

class ProfessionalHistoryScreen extends StatefulWidget {
  const ProfessionalHistoryScreen({super.key});

  @override
  State<ProfessionalHistoryScreen> createState() => _ProfessionalHistoryScreenState();
}

class _ProfessionalHistoryScreenState extends State<ProfessionalHistoryScreen> {
  final _service = ServiceRequestService.instance;
  final _searchController = TextEditingController();

  List<ServiceRequest> _requests = [];
  bool _loading = true;
  String? _error;
  String _status = 'Todos os Status';

  final _statusOptions = const [
    'Todos os Status',
    'Em andamento',
    'Concluído',
    'Cancelado',
  ];

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
        _requests = all
            .where(
              (r) =>
                  r.status == ServiceStatus.inProgress ||
                  r.status == ServiceStatus.completed ||
                  r.status == ServiceStatus.cancelled,
            )
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
        _error = 'Não foi possível carregar o histórico.';
        _loading = false;
      });
    }
  }

  List<ServiceRequest> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _requests.where((request) {
      final matchesStatus = switch (_status) {
        'Em andamento' => request.status == ServiceStatus.inProgress,
        'Concluído' => request.status == ServiceStatus.completed,
        'Cancelado' => request.status == ServiceStatus.cancelled,
        _ => true,
      };
      if (!matchesStatus) return false;

      if (query.isEmpty) return true;

      final haystack = [
        request.title,
        request.description,
        request.location,
        request.category ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  double get _totalBilled {
    return _requests
        .where((r) => r.status == ServiceStatus.completed)
        .fold<double>(0, (sum, r) => sum + _serviceValue(r));
  }

  double _serviceValue(ServiceRequest request) {
    return request.budget ??
        request.budgetMax ??
        request.budgetMin ??
        0;
  }

  String _formatMoney(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $fixed';
  }

  String _statusLabel(ServiceStatus status) {
    return switch (status) {
      ServiceStatus.pending => 'Aguardando',
      ServiceStatus.inProgress => 'Em andamento',
      ServiceStatus.completed => 'Concluído',
      ServiceStatus.cancelled => 'Cancelado',
    };
  }

  Color _statusColor(ServiceStatus status) {
    return switch (status) {
      ServiceStatus.pending => AppColors.warning,
      ServiceStatus.inProgress => AppColors.primary,
      ServiceStatus.completed => AppColors.success,
      ServiceStatus.cancelled => AppColors.danger,
    };
  }

  String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return ProfessionalPageScaffold(
      title: 'Histórico de Serviços',
      subtitle: 'Todos os seus serviços',
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 560;
                  final search = TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar serviços...',
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
                  );
                  final filter = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _status,
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list, size: 20),
                        items: _statusOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _status = v);
                        },
                      ),
                    ),
                  );

                  if (stack) {
                    return Column(
                      children: [
                        search,
                        const SizedBox(height: 10),
                        filter,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      SizedBox(width: 200, child: filter),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Total de serviços encontrados: ${filtered.length}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _MessageCard(
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            else if (filtered.isEmpty)
              const _MessageCard(
                child: Column(
                  children: [
                    Text(
                      'Nenhum serviço encontrado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tente ajustar os filtros de busca',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryCard(
                    request: request,
                    statusLabel: _statusLabel(request.status),
                    statusColor: _statusColor(request.status),
                    dateLabel: _dateLabel(request.scheduledAt),
                    valueLabel: request.status == ServiceStatus.completed
                        ? _formatMoney(_serviceValue(request))
                        : null,
                    onDetails: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(request: request),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Estatísticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _HistoryStat(
                      value: '${_requests.length}',
                      label: 'Total de Serviços',
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _HistoryStat(
                      value: _formatMoney(_totalBilled),
                      label: 'Total Faturado',
                      color: AppColors.success,
                    ),
                  ),
                  const Expanded(
                    child: _HistoryStat(
                      value: '—',
                      label: 'Nota Média',
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Widget child;

  const _MessageCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ServiceRequest request;
  final String statusLabel;
  final Color statusColor;
  final String dateLabel;
  final String? valueLabel;
  final VoidCallback onDetails;

  const _HistoryCard({
    required this.request,
    required this.statusLabel,
    required this.statusColor,
    required this.dateLabel,
    required this.onDetails,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Agendado para $dateLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (valueLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Valor: $valueLabel',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
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
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Ver detalhes',
            icon: Icons.visibility_outlined,
            color: AppColors.primary,
            onTap: onDetails,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
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
            border: Border.all(color: color),
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

class _HistoryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HistoryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
