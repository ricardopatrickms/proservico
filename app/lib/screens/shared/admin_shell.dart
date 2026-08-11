import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/helpers.dart';
import '../auth/welcome_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboardScreen(onOpenApprovals: () => setState(() => _index = 3)),
      const AdminPeopleScreen(type: AccountType.client),
      const AdminPeopleScreen(type: AccountType.professional),
      const AdminApprovalsScreen(),
      const AdminServicesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering), label: 'Profissionais'),
          NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified), label: 'Aprovações'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman), label: 'Serviços'),
        ],
      ),
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  final VoidCallback onOpenApprovals;

  const AdminDashboardScreen({super.key, required this.onOpenApprovals});

  @override
  Widget build(BuildContext context) {
    final store = MockStore.instance;
    final clients = store.adminPeople.where((p) => p.type == AccountType.client).length;
    final pros = store.adminPeople.where((p) => p.type == AccountType.professional).length;
    final pending = store.adminPeople.where((p) => p.type == AccountType.professional && !p.approved).length;
    final services = store.clientRequests.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Visão geral da operação',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Clientes', value: '$clients', icon: Icons.people_outline, color: AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Profissionais', value: '$pros', icon: Icons.engineering_outlined, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Aguardando', value: '$pending', icon: Icons.hourglass_top, color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Solicitações', value: '$services', icon: Icons.list_alt, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 20),
          if (pending > 0)
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_outlined, color: AppColors.warning),
                title: Text('$pending cadastro(s) aguardando aprovação'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenApprovals,
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPeopleScreen extends StatelessWidget {
  final AccountType type;

  const AdminPeopleScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final people = MockStore.instance.adminPeople.where((p) => p.type == type).toList();
    final isClient = type == AccountType.client;

    return Scaffold(
      appBar: AppBar(title: Text(isClient ? 'Gestão de clientes' : 'Gestão de profissionais')),
      body: people.isEmpty
          ? EmptyState(
              icon: isClient ? Icons.people_outline : Icons.engineering_outlined,
              title: 'Nenhum registro',
              message: 'Os cadastros aparecerão aqui.',
            )
          : ListView.separated(
              itemCount: people.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final person = people[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(person.name[0], style: const TextStyle(color: AppColors.primary)),
                  ),
                  title: Text(person.name),
                  subtitle: Text('${person.email}\n${person.phone}'),
                  isThreeLine: true,
                  trailing: isClient
                      ? null
                      : Chip(
                          label: Text(person.approved ? 'Aprovado' : 'Pendente'),
                          backgroundColor: person.approved
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.warning.withValues(alpha: 0.12),
                        ),
                );
              },
            ),
    );
  }
}

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  @override
  Widget build(BuildContext context) {
    final pending = MockStore.instance.adminPeople
        .where((p) => p.type == AccountType.professional && !p.approved)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovação de cadastros')),
      body: pending.isEmpty
          ? const EmptyState(
              icon: Icons.verified_outlined,
              title: 'Nada pendente',
              message: 'Não há cadastros aguardando aprovação.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final person = pending[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(person.email, style: const TextStyle(color: AppColors.textSecondary)),
                        Text(person.phone, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  MockStore.instance.adminPeople.removeWhere((p) => p.id == person.id);
                                  showAppSnackBar(context, 'Cadastro recusado');
                                  setState(() {});
                                },
                                child: const Text('Recusar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  MockStore.instance.setPersonApproval(person.id, true);
                                  showAppSnackBar(context, 'Cadastro aprovado');
                                  setState(() {});
                                },
                                child: const Text('Aprovar'),
                              ),
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

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = MockStore.instance.clientRequests;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de serviços')),
      body: requests.isEmpty
          ? const EmptyState(
              icon: Icons.handyman_outlined,
              title: 'Sem solicitações',
              message: 'As solicitações de serviço aparecerão aqui.',
            )
          : ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final request = requests[index];
                return ListTile(
                  title: Text(request.title),
                  subtitle: Text('${request.location}\n${formatDate(request.scheduledAt)}'),
                  isThreeLine: true,
                  trailing: Text(
                    request.status.name,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
    );
  }
}
