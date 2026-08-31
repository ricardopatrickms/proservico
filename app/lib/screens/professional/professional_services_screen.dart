import 'package:flutter/material.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/professional_service_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/helpers.dart';
import 'service_form_screen.dart';

class ProfessionalServicesScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const ProfessionalServicesScreen({super.key, this.onChanged});

  @override
  State<ProfessionalServicesScreen> createState() => _ProfessionalServicesScreenState();
}

class _ProfessionalServicesScreenState extends State<ProfessionalServicesScreen> {
  final _service = ProfessionalServiceService.instance;

  List<ProfessionalService> _services = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final services = await _service.list();
      if (!mounted) return;
      setState(() {
        _services = services;
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

  Future<void> _openForm({ProfessionalService? service}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ServiceFormScreen(service: service)),
    );
    if (changed == true && mounted) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _toggleActive(ProfessionalService service, bool value) async {
    if (_busyId != null) return;
    setState(() => _busyId = service.id);
    try {
      final updated = await _service.update(service.id, active: value);
      if (!mounted) return;
      setState(() {
        _services = [
          for (final item in _services)
            if (item.id == updated.id) updated else item,
        ];
      });
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível atualizar o serviço.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(ProfessionalService service) async {
    if (_busyId != null) return;
    setState(() => _busyId = service.id);
    try {
      await _service.delete(service.id);
      if (!mounted) return;
      setState(() {
        _services = _services.where((s) => s.id != service.id).toList();
      });
      showAppSnackBar(context, 'Serviço removido');
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível remover o serviço.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus serviços')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.error_outline,
                        title: 'Não foi possível carregar',
                        message: _error!,
                        actionLabel: 'Tentar novamente',
                        onAction: _load,
                      ),
                    ],
                  )
                : _services.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.handyman_outlined,
                            title: 'Sem serviços cadastrados',
                            message: 'Cadastre os serviços que você oferece.',
                            actionLabel: 'Cadastrar serviço',
                            onAction: () => _openForm(),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          final busy = _busyId == service.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          service.title,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                      Switch(
                                        value: service.active,
                                        onChanged: busy ? null : (value) => _toggleActive(service, value),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    service.category,
                                    style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(service.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'A partir de ${formatCurrency(service.priceFrom)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: busy ? null : () => _openForm(service: service),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        label: const Text('Editar'),
                                      ),
                                      TextButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () {
                                                showConfirmDialog(
                                                  context: context,
                                                  title: 'Excluir serviço',
                                                  message: 'Deseja remover "${service.title}"?',
                                                  onConfirm: () => _remove(service),
                                                );
                                              },
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        label: const Text('Excluir', style: TextStyle(color: AppColors.danger)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
