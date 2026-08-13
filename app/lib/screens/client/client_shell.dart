import 'package:flutter/material.dart';

import '../../data/client_requests_store.dart';
import '../../data/mock_store.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_menu_screen.dart';
import '../auth/welcome_screen.dart';
import 'client_dashboard_screen.dart';
import 'client_profile_screen.dart';
import 'client_proposals_screen.dart';
import 'client_services_screen.dart';
import 'request_service_screen.dart';
import 'settings_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  /// 0 = Menu, 1 = Dashboard, 2 = Solicitar, 3 = Serviços, 4 = Perfil
  int _tab = 1;
  int _pageIndex = 0;

  late final List<Widget> _pages = [
    ClientDashboardScreen(onRequestService: () => _goToTab(2)),
    RequestServiceScreen(onSubmitted: () => _goToTab(3)),
    const ClientServicesScreen(),
    const ClientProfileScreen(),
  ];

  String get _userName {
    final name = MockStore.instance.currentUser?.name.trim() ?? 'Cliente';
    return name.isEmpty ? 'Cliente' : name.split(RegExp(r'\s+')).first;
  }

  void _goToTab(int tab) {
    setState(() {
      _tab = tab;
      if (tab > 0) _pageIndex = tab - 1;
    });
    // IndexedStack mantém a tela viva — recarrega ao abrir Meus Serviços.
    if (tab == 3) {
      ClientRequestsStore.instance.load();
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    ClientRequestsStore.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _menuPage() {
    return AppMenuScreen(
      title: 'Menu',
      subtitle: 'Olá, $_userName',
      items: [
        AppMenuItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          onTap: () => _goToTab(1),
        ),
        AppMenuItem(
          label: 'Solicitar Serviço',
          icon: Icons.add_circle_outline,
          onTap: () => _goToTab(2),
        ),
        AppMenuItem(
          label: 'Meus Serviços',
          icon: Icons.list_alt_outlined,
          onTap: () => _goToTab(3),
        ),
        AppMenuItem(
          label: 'Propostas Recebidas',
          icon: Icons.description_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientProposalsScreen()),
            );
          },
        ),
        AppMenuItem(
          label: 'Meu Perfil',
          icon: Icons.person_outline,
          onTap: () => _goToTab(4),
        ),
        AppMenuItem(
          label: 'Configurações',
          icon: Icons.settings_outlined,
          onTap: _openSettings,
        ),
      ],
      footerItems: [
        AppMenuItem(
          label: 'Sair',
          icon: Icons.logout,
          danger: true,
          onTap: _logout,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _tab == 0
          ? _menuPage()
          : IndexedStack(index: _pageIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Solicitar',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Serviços',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
