import 'package:flutter/material.dart';

import '../../models/service_request.dart';
import '../../models/user.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
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

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenApprovals;

  const AdminDashboardScreen({super.key, required this.onOpenApprovals});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = AdminService.instance;
  AdminDashboardStats? _stats;
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
      final stats = await _api.dashboard();
      if (!mounted) return;
      setState(() {
        _stats = stats;
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
        _error = 'Não foi possível carregar o painel.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final pending = stats?.pendingApprovals ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
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
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Visão geral da operação',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Clientes',
                              value: '${stats?.clients ?? 0}',
                              icon: Icons.people_outline,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Profissionais',
                              value: '${stats?.professionals ?? 0}',
                              icon: Icons.engineering_outlined,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Aguardando',
                              value: '$pending',
                              icon: Icons.hourglass_top,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Solicitações',
                              value: '${stats?.serviceRequests ?? 0}',
                              icon: Icons.list_alt,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (pending > 0)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.verified_outlined, color: AppColors.warning),
                            title: Text('$pending cadastro(s) aguardando aprovação'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: widget.onOpenApprovals,
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class AdminPeopleScreen extends StatefulWidget {
  final AccountType type;

  const AdminPeopleScreen({super.key, required this.type});

  @override
  State<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends State<AdminPeopleScreen> {
  final _api = AdminService.instance;
  List<AppUser> _people = [];
  bool _loading = true;
  String? _error;

  bool get _isClient => widget.type == AccountType.client;

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
      final people = await _api.users(type: widget.type.apiValue);
      if (!mounted) return;
      setState(() {
        _people = people;
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
        _error = 'Não foi possível carregar os cadastros.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isClient ? 'Gestão de clientes' : 'Gestão de profissionais')),
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
                : _people.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(
                            icon: _isClient ? Icons.people_outline : Icons.engineering_outlined,
                            title: 'Nenhum registro',
                            message: 'Os cadastros aparecerão aqui.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _people.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final person = _people[index];
                          final initial = person.name.trim().isNotEmpty
                              ? person.name.trim()[0].toUpperCase()
                              : '?';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              child: Text(initial, style: const TextStyle(color: AppColors.primary)),
                            ),
                            title: Text(person.name),
                            subtitle: Text('${person.email}\n${person.phone}'),
                            isThreeLine: true,
                            trailing: _isClient
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
  final _api = AdminService.instance;
  List<AppUser> _pending = [];
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
      final pending = await _api.users(type: 'professional', approved: false);
      if (!mounted) return;
      setState(() {
        _pending = pending;
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
        _error = 'Não foi possível carregar as aprovações.';
        _loading = false;
      });
    }
  }

  Future<void> _setApproval(AppUser person, {required bool approved}) async {
    if (_busyId != null) return;
    setState(() => _busyId = person.id);
    try {
      await _api.setApproval(person.id, approved: approved);
      if (!mounted) return;
      setState(() {
        _pending = _pending.where((p) => p.id != person.id).toList();
      });
      showAppSnackBar(context, approved ? 'Cadastro aprovado' : 'Cadastro recusado');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível atualizar o cadastro.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aprovação de cadastros')),
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
                : _pending.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          const EmptyState(
                            icon: Icons.verified_outlined,
                            title: 'Nada pendente',
                            message: 'Não há cadastros aguardando aprovação.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _pending.length,
                        itemBuilder: (context, index) {
                          final person = _pending[index];
                          final busy = _busyId == person.id;
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
                                          onPressed: busy ? null : () => _setApproval(person, approved: false),
                                          child: const Text('Recusar'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: busy ? null : () => _setApproval(person, approved: true),
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
      ),
    );
  }
}

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final _api = AdminService.instance;
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
      final requests = await _api.serviceRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
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
        _error = 'Não foi possível carregar as solicitações.';
        _loading = false;
      });
    }
  }

  String _statusLabel(ServiceStatus status) => switch (status) {
        ServiceStatus.pending => 'Pendente',
        ServiceStatus.inProgress => 'Em andamento',
        ServiceStatus.completed => 'Concluído',
        ServiceStatus.cancelled => 'Cancelado',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de serviços')),
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
                : _requests.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          const EmptyState(
                            icon: Icons.handyman_outlined,
                            title: 'Sem solicitações',
                            message: 'As solicitações de serviço aparecerão aqui.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final request = _requests[index];
                          return ListTile(
                            title: Text(request.title),
                            subtitle: Text('${request.location}\n${formatDate(request.scheduledAt)}'),
                            isThreeLine: true,
                            trailing: Text(
                              _statusLabel(request.status),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
