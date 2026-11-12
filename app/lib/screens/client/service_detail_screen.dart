import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../../widgets/service_cards.dart';
import '../professional/complete_service_sheet.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceRequest request;

  /// Quando true, mostra ações do profissional (Iniciar / Finalizar).
  final bool forProfessional;

  const ServiceDetailScreen({
    super.key,
    required this.request,
    this.forProfessional = false,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late ServiceRequest _request;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  bool get _canStart =>
      widget.forProfessional &&
      _request.status == ServiceStatus.inProgress &&
      !_request.hasStarted;

  bool get _canFinish =>
      widget.forProfessional &&
      _request.status == ServiceStatus.inProgress &&
      _request.hasStarted;

  String get _statusLabel {
    if (_request.status == ServiceStatus.inProgress) {
      return _request.hasStarted ? 'Em andamento' : 'Aceito';
    }
    return switch (_request.status) {
      ServiceStatus.pending => 'Pendente',
      ServiceStatus.awaitingPayment => 'Aguardando pagamento',
      ServiceStatus.completed => 'Concluído',
      ServiceStatus.cancelled => 'Cancelado',
      ServiceStatus.inProgress => 'Em andamento',
    };
  }

  Color get _statusColor {
    if (_request.status == ServiceStatus.inProgress && !_request.hasStarted) {
      return AppColors.success;
    }
    return switch (_request.status) {
      ServiceStatus.pending => AppColors.warning,
      ServiceStatus.awaitingPayment => AppColors.warning,
      ServiceStatus.inProgress => AppColors.primary,
      ServiceStatus.completed => AppColors.success,
      ServiceStatus.cancelled => AppColors.danger,
    };
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final updated = await ServiceRequestService.instance.start(_request.id);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _busy = false;
        _changed = true;
      });
      showAppSnackBar(context, 'Serviço iniciado.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackBar(context, 'Não foi possível iniciar o serviço.');
    }
  }

  Future<void> _finish() async {
    final updated = await showCompleteServiceSheet(
      context: context,
      request: _request,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _request = updated;
      _changed = true;
    });
    showAppSnackBar(context, 'Serviço finalizado.');
    Navigator.pop(context, _request);
  }

  void _pop() {
    Navigator.pop(context, _changed ? _request : null);
  }

  @override
  Widget build(BuildContext context) {
    final photoUrls =
        _request.photoUrls.map(ApiConfig.resolveStorageUrl).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalhe do serviço'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : _pop,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _request.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            UrgencyBadge(urgency: _request.urgency),
            const SizedBox(height: 16),
            _InfoTile(
              icon: Icons.description_outlined,
              label: 'Descrição',
              value: _request.description,
            ),
            _InfoTile(
              icon: Icons.place_outlined,
              label: 'Localização',
              value: _request.location,
            ),
            _InfoTile(
              icon: Icons.schedule,
              label: 'Data e horário',
              value: formatDate(_request.scheduledAt),
            ),
            if (_request.budget != null)
              _InfoTile(
                icon: Icons.attach_money,
                label: 'Orçamento',
                value: formatCurrency(_request.budget!),
              ),
            _InfoTile(
              icon: Icons.inventory_2_outlined,
              label: 'Materiais',
              value: _request.needsMaterials
                  ? 'Cliente solicita materiais'
                  : 'Não precisa de materiais',
            ),
            if (_request.preferences.isNotEmpty)
              _InfoTile(
                icon: Icons.tune,
                label: 'Preferências',
                value: _request.preferences,
              ),
            if (_request.professionalName != null)
              _InfoTile(
                icon: Icons.engineering_outlined,
                label: 'Profissional',
                value: _request.professionalName!,
              ),
            if (photoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photoUrls[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_request.photoLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _request.photoLabels
                    .map(
                      (p) => Chip(
                        avatar: const Icon(Icons.image_outlined, size: 18),
                        label: Text(p),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        bottomNavigationBar: (_canStart || _canFinish)
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ElevatedButton.icon(
                    onPressed: _busy
                        ? null
                        : (_canStart ? _start : _finish),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_canStart ? Icons.play_arrow : Icons.check),
                    label: Text(
                      _canStart ? 'Iniciar serviço' : 'Finalizar serviço',
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
