import 'package:flutter/material.dart';

import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/auth_service.dart';
import '../../services/session_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_menu_screen.dart';
import '../auth/login_screen.dart';
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
  /// Barra inferior: 0 = Dashboard, 1 = Solicitar, 2 = Serviços, 3 = Perfil
  int _bottomTab = 0;

  /// IndexedStack: 0 = Dashboard, 1 = Solicitar, 2 = Serviços, 3 = Propostas, 4 = Perfil
  int _pageIndex = 0;

  bool _showingMenu = false;

  ServiceRequest? _proposalsFilter;

  /// Aba da barra para a qual o "voltar" das propostas retorna.
  int _proposalsReturnTab = 0;

  static const int _proposalsPageIndex = 3;
  static const int _profilePageIndex = 4;

  late final Widget _dashboardPage = ClientDashboardScreen(
    onRequestService: () => _goToBottomTab(1),
    onOpenProposals: _openProposals,
    onOpenMenu: _openMenu,
  );
  late final Widget _requestPage = RequestServiceScreen(
    onSubmitted: () => _goToBottomTab(2),
    onOpenMenu: _openMenu,
  );
  late final Widget _servicesPage = ClientServicesScreen(
    onOpenProposals: _openProposals,
    onOpenMenu: _openMenu,
  );
  late final Widget _profilePage = ClientProfileScreen(
    onOpenMenu: _openMenu,
  );

  String get _userName {
    final name = SessionStore.instance.currentUser?.name.trim() ?? 'Cliente';
    return name.isEmpty ? 'Cliente' : name.split(RegExp(r'\s+')).first;
  }

  int get _bottomSelectedIndex {
    if (_pageIndex == _proposalsPageIndex) return _proposalsReturnTab.clamp(0, 3);
    return _bottomTab;
  }

  void _openMenu() => setState(() => _showingMenu = true);

  void _closeMenu() => setState(() => _showingMenu = false);

  void _goToBottomTab(int tab) {
    setState(() {
      _showingMenu = false;
      _bottomTab = tab;
      _proposalsFilter = null;
      _pageIndex = switch (tab) {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => _profilePageIndex,
        _ => 0,
      };
    });
    if (tab == 2) {
      ClientRequestsStore.instance.load();
    }
  }

  void _openProposals([ServiceRequest? request]) {
    setState(() {
      _showingMenu = false;
      if (_pageIndex != _proposalsPageIndex) {
        _proposalsReturnTab = _bottomTab;
      }
      _proposalsFilter = request;
      _pageIndex = _proposalsPageIndex;
    });
    ClientRequestsStore.instance.load();
  }

  void _closeProposals() => _goToBottomTab(_proposalsReturnTab);

  Future<void> _logout() async {
    await AuthService.instance.logout();
    ClientRequestsStore.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _menuPage() {
    return AppMenuScreen(
      title: 'Menu',
      subtitle: 'Olá, $_userName',
      onClose: _closeMenu,
      items: [
        AppMenuItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          onTap: () => _goToBottomTab(0),
        ),
        AppMenuItem(
          label: 'Solicitar Serviço',
          icon: Icons.add_circle_outline,
          onTap: () => _goToBottomTab(1),
        ),
        AppMenuItem(
          label: 'Meus Serviços',
          icon: Icons.list_alt_outlined,
          onTap: () => _goToBottomTab(2),
        ),
        AppMenuItem(
          label: 'Propostas Recebidas',
          icon: Icons.description_outlined,
          onTap: () => _openProposals(),
        ),
        AppMenuItem(
          label: 'Meu Perfil',
          icon: Icons.person_outline,
          onTap: () => _goToBottomTab(3),
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
      body: _showingMenu
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
                  onBack: _closeProposals,
                ),
                _profilePage,
              ],
            ),
      bottomNavigationBar: _showingMenu
          ? null
          : NavigationBarTheme(
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
                onDestinationSelected: _goToBottomTab,
                destinations: const [
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
