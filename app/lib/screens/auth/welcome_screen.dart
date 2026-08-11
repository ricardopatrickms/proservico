import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';
import '../shared/admin_shell.dart';
import 'login_screen.dart';
import 'professional_register_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(fontSize: 20),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Conectando quem precisa a quem faz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A plataforma completa para encontrar profissionais qualificados ou oferecer seus serviços',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _RoleCard(
                      icon: Icons.person_search_outlined,
                      title: 'Precisa de um serviço?',
                      description: 'Encontre profissionais perto de você e solicite com praticidade.',
                      background: AppColors.surface,
                      titleColor: AppColors.navy,
                      iconColor: AppColors.primary,
                      descriptionColor: AppColors.textSecondary,
                      primaryLabel: 'Sou cliente',
                      primaryColor: AppColors.primary,
                      primaryForeground: Colors.white,
                      secondaryLabel: 'Entrar',
                      onPrimary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      onSecondary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      icon: Icons.work_outline,
                      title: 'É um profissional?',
                      description: 'Cadastre-se e comece a receber pedidos na sua região.',
                      background: AppColors.accent,
                      titleColor: Colors.white,
                      iconColor: Colors.white,
                      descriptionColor: Colors.white.withValues(alpha: 0.9),
                      primaryLabel: 'Sou profissional',
                      primaryColor: Colors.white,
                      primaryForeground: AppColors.accent,
                      secondaryLabel: 'Entrar',
                      onPrimary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfessionalRegisterScreen(),
                          ),
                        );
                      },
                      onSecondary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminShell()),
                        );
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.white60),
                      child: const Text('Acesso administrativo'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color background;
  final Color titleColor;
  final Color iconColor;
  final Color descriptionColor;
  final String primaryLabel;
  final Color primaryColor;
  final Color primaryForeground;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.background,
    required this.titleColor,
    required this.iconColor,
    required this.descriptionColor,
    required this.primaryLabel,
    required this.primaryColor,
    required this.primaryForeground,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: descriptionColor, fontSize: 13, height: 1.35)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: primaryForeground,
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(primaryLabel),
          ),
          const SizedBox(height: 8),
          if (background == AppColors.accent)
            ElevatedButton(
              onPressed: onSecondary,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(secondaryLabel),
            )
          else
            OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(secondaryLabel),
            ),
        ],
      ),
    );
  }
}
