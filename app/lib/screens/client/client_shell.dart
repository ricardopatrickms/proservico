import 'package:flutter/material.dart';

import '../../data/client_requests_store.dart';
import '../../data/mock_store.dart';
import '../../models/service_request.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_menu_screen.dart';
import '../auth/welcome_screen.dart';
import 'client_dashboard_screen.dart';
import 'client_profile_screen.dart';
import 'client_proposals_screen.dart';
import 'client_services_screen.dart';
import 'request_service_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  /// 0 = Menu, 1 = Dashboard, 2 = Solicitar, 3 = Serviços, 4 = Perfil
  int _tab = 1;

  /// 0 = Dashboard, 1 = Solicitar, 2 = Serviços, 3 = Propostas, 4 = Perfil
  int _pageIndex = 0;

  ServiceRequest? _proposalsFilter;

  static const int _proposalsPageIndex = 3;
  static const int _profilePageIndex = 4;

  late final Widget _dashboardPage = ClientDashboardScreen(
    onRequestService: () => _goToTab(2),
  );
  late final Widget _requestPage = RequestServiceScreen(
    onSubmitted: () => _goToTab(3),
  );
  late final Widget _servicesPage = ClientServicesScreen(
    onOpenProposals: _openProposals,
  );
  late final Widget _profilePage = const ClientProfileScreen();

  String get _userName {
    final name = MockStore.instance.currentUser?.name.trim() ?? 'Cliente';
    return name.isEmpty ? 'Cliente' : name.split(RegExp(r'\s+')).first;
  }

  int get _bottomSelectedIndex {
    // Propostas fica fora da barra: destaca Menu (origem da navegação).
    if (_pageIndex == _proposalsPageIndex) return 0;
    return _tab;
  }

  void _goToTab(int tab) {
    setState(() {
      _tab = tab;
      _proposalsFilter = null;
      if (tab == 0) {
        // Volta ao menu; sai da página de propostas se estiver nela.
        if (_pageIndex == _proposalsPageIndex) _pageIndex = 0;
        return;
      }
      _pageIndex = switch (tab) {
        1 => 0,
        2 => 1,
        3 => 2,
        4 => _profilePageIndex,
        _ => 0,
      };
    });
    if (tab == 3) {
      ClientRequestsStore.instance.load();
    }
  }

  void _openProposals([ServiceRequest? request]) {
    setState(() {
      _proposalsFilter = request;
      _pageIndex = _proposalsPageIndex;
      // Mantém body no IndexedStack (tab != 0); a barra destaca Menu.
      _tab = 1;
    });
    ClientRequestsStore.instance.load();
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
          onTap: () => _openProposals(),
        ),
        AppMenuItem(
          label: 'Meu Perfil',
          icon: Icons.person_outline,
          onTap: () => _goToTab(4),
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
    final showingMenu = _tab == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: showingMenu
          ? _menuPage()
          : IndexedStack(
              index: _pageIndex,
              children: [
                _dashboardPage,
                _requestPage,
                _servicesPage,
                ClientProposalsScreen(
                  key: ValueKey(_proposalsFilter?.id ?? 'all'),
                  request: _proposalsFilter,
                ),
                _profilePage,
              ],
            ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _bottomSelectedIndex,
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
      ),
    );
  }
}
