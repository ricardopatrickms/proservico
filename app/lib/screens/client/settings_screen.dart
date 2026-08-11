import 'package:flutter/material.dart';

import '../../data/client_requests_store.dart';
import '../../data/mock_store.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../auth/welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    ClientRequestsStore.instance.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  void _comingSoon(BuildContext context) {
    showAppSnackBar(context, 'Disponível em um próximo módulo');
  }

  @override
  Widget build(BuildContext context) {
    final user = MockStore.instance.currentUser!;
    final roleLabel = switch (user.type.name) {
      'professional' => 'Profissional',
      'admin' => 'Administrador',
      _ => 'Cliente',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificações'),
            subtitle: const Text('Alertas de serviços e atualizações'),
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacidade'),
            subtitle: const Text('Controle de dados da conta'),
            trailing: const Text(
              'Em breve',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            onTap: () => _comingSoon(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ajuda & Suporte'),
            subtitle: const Text('Dúvidas frequentes'),
            trailing: const Text(
              'Em breve',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            onTap: () => _comingSoon(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            subtitle: Text('ProServiço • $roleLabel • Módulo 1'),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Sair', style: TextStyle(color: AppColors.danger)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
