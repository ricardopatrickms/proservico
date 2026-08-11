import 'package:flutter/material.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../client/service_detail_screen.dart';
import 'professional_placeholder_screen.dart';

class ProfessionalInProgressScreen extends StatefulWidget {
  const ProfessionalInProgressScreen({super.key});

  @override
  State<ProfessionalInProgressScreen> createState() =>
      _ProfessionalInProgressScreenState();
}

class _ProfessionalInProgressScreenState
    extends State<ProfessionalInProgressScreen> {
  final _service = ServiceRequestService.instance;

  List<ServiceRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
            .where((r) => r.status == ServiceStatus.inProgress)
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
        _error = 'Não foi possível carregar os serviços.';
        _loading = false;
      });
    }
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
    return ProfessionalPageScaffold(
      title: 'Serviços em Andamento',
      subtitle: 'Acompanhe os serviços em execução',
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Total de serviços encontrados: ${_requests.length}',
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
            else if (_requests.isEmpty)
              const _MessageCard(
                child: Column(
                  children: [
                    Text(
                      'Nenhum serviço em andamento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Quando você aceitar um pedido, ele aparecerá aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ..._requests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InProgressCard(
                    request: request,
                    statusLabel: _statusLabel(request.status),
                    statusColor: _statusColor(request.status),
                    dateLabel: _dateLabel(request.scheduledAt),
                    onDetails: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(request: request),
                        ),
                      );
                    },
                    onMessage: () {
                      showAppSnackBar(context, 'Mensagens em breve.');
                    },
                  ),
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
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InProgressCard extends StatelessWidget {
  final ServiceRequest request;
  final String statusLabel;
  final Color statusColor;
  final String dateLabel;
  final VoidCallback onDetails;
  final VoidCallback onMessage;

  const _InProgressCard({
    required this.request,
    required this.statusLabel,
    required this.statusColor,
    required this.dateLabel,
    required this.onDetails,
    required this.onMessage,
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
          Row(
            children: [
              _ActionButton(
                label: 'Ver detalhes',
                icon: Icons.visibility_outlined,
                color: AppColors.primary,
                onTap: onDetails,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                label: 'Mensagem',
                icon: Icons.chat_bubble_outline,
                color: AppColors.textSecondary,
                borderColor: AppColors.border,
                onTap: onMessage,
              ),
            ],
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
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
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
