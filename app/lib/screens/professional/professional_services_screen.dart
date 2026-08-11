import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../models/service_request.dart';
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
  void _refresh() {
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _openForm({ProfessionalService? service}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ServiceFormScreen(service: service)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final services = MockStore.instance.professionalServices;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus serviços')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: services.isEmpty
          ? EmptyState(
              icon: Icons.handyman_outlined,
              title: 'Sem serviços cadastrados',
              message: 'Cadastre os serviços que você oferece.',
              actionLabel: 'Cadastrar serviço',
              onAction: () => _openForm(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
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
                              onChanged: (value) {
                                MockStore.instance.updateProfessionalService(
                                  service.copyWith(active: value),
                                );
                                _refresh();
                              },
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
                              onPressed: () => _openForm(service: service),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Editar'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                showConfirmDialog(
                                  context: context,
                                  title: 'Excluir serviço',
                                  message: 'Deseja remover "${service.title}"?',
                                  onConfirm: () {
                                    MockStore.instance.removeProfessionalService(service.id);
                                    showAppSnackBar(context, 'Serviço removido');
                                    _refresh();
                                  },
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
    );
  }
}
