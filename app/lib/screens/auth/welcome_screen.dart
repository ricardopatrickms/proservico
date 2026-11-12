import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';
import 'login_screen.dart';
import 'professional_register_screen.dart';
import 'register_screen.dart';

/// Escolha do tipo de cadastro (cliente ou profissional).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _backToLogin(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _backToLogin(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Voltar ao login',
                  ),
                  const BrandLogo(fontSize: 20),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Como você quer se cadastrar?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Escolha o tipo de conta para começar a usar o ProServiço',
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
                      description:
                          'Encontre profissionais perto de você e solicite com praticidade.',
                      background: AppColors.surface,
                      titleColor: AppColors.navy,
                      iconColor: AppColors.primary,
                      descriptionColor: AppColors.textSecondary,
                      primaryLabel: 'Sou cliente',
                      primaryColor: AppColors.primary,
                      primaryForeground: Colors.white,
                      onPrimary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      icon: Icons.work_outline,
                      title: 'É um profissional?',
                      description:
                          'Cadastre-se e comece a receber pedidos na sua região.',
                      background: AppColors.accent,
                      titleColor: Colors.white,
                      iconColor: Colors.white,
                      descriptionColor: Colors.white.withValues(alpha: 0.9),
                      primaryLabel: 'Sou profissional',
                      primaryColor: Colors.white,
                      primaryForeground: AppColors.accent,
                      onPrimary: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfessionalRegisterScreen(),
                          ),
                        );
                      },
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
  final VoidCallback onPrimary;

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
    required this.onPrimary,
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
          Text(
            description,
            style: TextStyle(color: descriptionColor, fontSize: 13, height: 1.35),
          ),
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
        ],
      ),
    );
  }
}
