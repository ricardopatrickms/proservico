import 'package:flutter/material.dart';

import '../../data/client_requests_store.dart';
import '../../data/mock_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/service_cards.dart';
import '../professional/professional_request_detail_sheet.dart';

class ClientDashboardScreen extends StatefulWidget {
  final VoidCallback onRequestService;

  const ClientDashboardScreen({super.key, required this.onRequestService});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  final _store = ClientRequestsStore.instance;

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

  @override
  Widget build(BuildContext context) {
    final user = MockStore.instance.currentUser;
    final name = user?.name ?? 'Cliente';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Painel Cliente'),
      ),
      body: RefreshIndicator(
        onRefresh: _store.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Olá, $name! 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bem-vindo ao seu painel. Aqui você pode gerenciar seus serviços e muito mais.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (_store.loading && _store.requests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    label: 'Pendentes',
                    value: '${_store.pendingCount}',
                    icon: Icons.schedule,
                    color: AppColors.warning,
                  ),
                  StatCard(
                    label: 'Andamento',
                    value: '${_store.inProgressCount}',
                    icon: Icons.timelapse,
                    color: AppColors.primary,
                  ),
                  StatCard(
                    label: 'Concluídos',
                    value: '${_store.completedCount}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  StatCard(
                    label: 'Total',
                    value: '${_store.totalCount}',
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.navy,
                  ),
                ],
              ),
              if (_store.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _store.error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: widget.onRequestService,
                icon: const Icon(Icons.add),
                label: const Text('Solicitar serviço'),
              ),
              const SizedBox(height: 28),
              const SectionHeader(
                title: 'Últimas atividades',
                subtitle: 'Acompanhe suas solicitações recentes',
              ),
              const SizedBox(height: 12),
              if (_store.requests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: AppColors.border),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum serviço encontrado. Que tal solicitar o primeiro?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: widget.onRequestService,
                        child: const Text('Solicitar serviço'),
                      ),
                    ],
                  ),
                )
              else
                ..._store.requests.take(3).map(
                  (request) => ServiceRequestCard(
                    request: request,
                    onTap: () => showProfessionalRequestDetail(context, request),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
