import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_menu_screen.dart';
import '../auth/welcome_screen.dart';
import 'professional_dashboard_screen.dart';
import 'professional_history_screen.dart';
import 'professional_in_progress_screen.dart';
import 'professional_profile_screen.dart';
import 'professional_received_screen.dart';
import 'professional_settings_screen.dart';

enum ProfessionalNav {
  dashboard,
  received,
  inProgress,
  history,
  profile,
  settings,
}

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({super.key});

  @override
  State<ProfessionalShell> createState() => _ProfessionalShellState();
}

class _ProfessionalShellState extends State<ProfessionalShell> {
  ProfessionalNav _nav = ProfessionalNav.dashboard;
  static const double _sidebarBreakpoint = 900;

  /// Em mobile: 0 = Menu, 1 = Dashboard, 2 = Histórico, 3 = Perfil
  int _mobileTab = 1;

  String get _userName {
    final name = MockStore.instance.currentUser?.name.trim() ?? 'Profissional';
    return name.isEmpty ? 'Profissional' : name.split(RegExp(r'\s+')).first;
  }

  String get _initial {
    final name = MockStore.instance.currentUser?.name.trim() ?? 'P';
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }

  Widget _pageFor(ProfessionalNav nav) {
    return switch (nav) {
      ProfessionalNav.dashboard => const ProfessionalDashboardScreen(),
      ProfessionalNav.history => const ProfessionalHistoryScreen(),
      ProfessionalNav.profile => const ProfessionalProfileScreen(),
      ProfessionalNav.settings => const ProfessionalSettingsScreen(),
      ProfessionalNav.received => const ProfessionalReceivedScreen(),
      ProfessionalNav.inProgress => const ProfessionalInProgressScreen(),
    };
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  void _selectNav(ProfessionalNav nav) {
    setState(() {
      _nav = nav;
      // Páginas fora da barra: fica no conteúdo com a aba do atalho mais próximo.
      // Menu (0) só quando o usuário abre a tela de menu de propósito.
      _mobileTab = switch (nav) {
        ProfessionalNav.dashboard => 1,
        ProfessionalNav.history => 2,
        ProfessionalNav.profile => 3,
        ProfessionalNav.received ||
        ProfessionalNav.inProgress ||
        ProfessionalNav.settings =>
          1, // Dashboard como âncora visual; o body mostra a página escolhida
      };
    });
  }

  void _onMobileDestinationSelected(int i) {
    setState(() {
      _mobileTab = i;
      if (i == 0) return;
      if (i == 1) _nav = ProfessionalNav.dashboard;
      if (i == 2) _nav = ProfessionalNav.history;
      if (i == 3) _nav = ProfessionalNav.profile;
    });
  }

  int _selectedBottomIndex() {
    if (_mobileTab == 0) return 0;
    return switch (_nav) {
      ProfessionalNav.history => 2,
      ProfessionalNav.profile => 3,
      _ => 1,
    };
  }

  Widget _mobileMenu() {
    return AppMenuScreen(
      title: 'Menu',
      subtitle: 'Olá, $_userName',
      items: [
        AppMenuItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          onTap: () => _selectNav(ProfessionalNav.dashboard),
        ),
        AppMenuItem(
          label: 'Serviços Recebidos',
          icon: Icons.assignment_outlined,
          onTap: () => _selectNav(ProfessionalNav.received),
        ),
        AppMenuItem(
          label: 'Serviços em Andamento',
          icon: Icons.schedule_outlined,
          onTap: () => _selectNav(ProfessionalNav.inProgress),
        ),
        AppMenuItem(
          label: 'Histórico de Serviços',
          icon: Icons.history,
          onTap: () => _selectNav(ProfessionalNav.history),
        ),
        AppMenuItem(
          label: 'Meu Perfil',
          icon: Icons.person_outline,
          onTap: () => _selectNav(ProfessionalNav.profile),
        ),
        AppMenuItem(
          label: 'Configurações',
          icon: Icons.settings_outlined,
          onTap: () => _selectNav(ProfessionalNav.settings),
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
    final wide = MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: wide
            ? Row(
                children: [
                  _ProfessionalSidebar(
                    selected: _nav,
                    userName: _userName,
                    initial: _initial,
                    onSelect: (n) => setState(() => _nav = n),
                    onLogout: _logout,
                  ),
                  Expanded(child: _pageFor(_nav)),
                ],
              )
            : (_mobileTab == 0 ? _mobileMenu() : _pageFor(_nav)),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _selectedBottomIndex(),
                onDestinationSelected: _onMobileDestinationSelected,
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
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: 'Histórico',
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

class _ProfessionalSidebar extends StatelessWidget {
  final ProfessionalNav selected;
  final String userName;
  final String initial;
  final ValueChanged<ProfessionalNav> onSelect;
  final VoidCallback onLogout;

  const _ProfessionalSidebar({
    required this.selected,
    required this.userName,
    required this.initial,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Painel Profissional',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Profissional',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _item(ProfessionalNav.dashboard, Icons.dashboard_outlined, 'Dashboard'),
                _item(ProfessionalNav.received, Icons.assignment_outlined, 'Serviços Recebidos'),
                _item(ProfessionalNav.inProgress, Icons.schedule_outlined, 'Serviços em Andamento'),
                _item(ProfessionalNav.history, Icons.history, 'Histórico de Serviços'),
                _item(ProfessionalNav.profile, Icons.person_outline, 'Meu Perfil'),
                _item(ProfessionalNav.settings, Icons.settings_outlined, 'Configurações'),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.logout, size: 20, color: AppColors.danger),
              title: const Text(
                'Sair',
                style: TextStyle(fontSize: 14, color: AppColors.danger),
              ),
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(ProfessionalNav nav, IconData icon, String label) {
    final active = selected == nav;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onSelect(nav),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
