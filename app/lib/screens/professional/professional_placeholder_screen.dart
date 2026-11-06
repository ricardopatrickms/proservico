import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProfessionalPlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const ProfessionalPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalPageScaffold(
      title: title,
      subtitle: subtitle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 56, color: AppColors.border),
              const SizedBox(height: 16),
              const Text(
                'Em breve',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expõe o callback do menu (☰) para as páginas do painel profissional.
class ProfessionalMenuScope extends InheritedWidget {
  final VoidCallback onOpenMenu;

  const ProfessionalMenuScope({
    super.key,
    required this.onOpenMenu,
    required super.child,
  });

  static ProfessionalMenuScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProfessionalMenuScope>();
  }

  @override
  bool updateShouldNotify(ProfessionalMenuScope oldWidget) =>
      onOpenMenu != oldWidget.onOpenMenu;
}

/// Layout comum das páginas do painel — AppBar igual ao do cliente.
class ProfessionalPageScaffold extends StatelessWidget {
  /// Título da AppBar (ex.: "Painel Profissional").
  final String title;

  /// Saudação/headline grande abaixo da AppBar (ex.: "Olá, Profi! 👋").
  final String? headline;

  /// Texto de apoio abaixo do headline (ou da AppBar, se não houver headline).
  final String? subtitle;

  final Widget child;
  final List<Widget>? actions;

  const ProfessionalPageScaffold({
    super.key,
    required this.title,
    this.headline,
    this.subtitle,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final onOpenMenu = ProfessionalMenuScope.maybeOf(context)?.onOpenMenu;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: onOpenMenu == null
            ? null
            : IconButton(
                onPressed: onOpenMenu,
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
              ),
        title: Text(title),
        actions: actions,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline != null || subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (headline != null)
                    Text(
                      headline!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (headline != null && subtitle != null)
                    const SizedBox(height: 6),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: headline != null ? 14 : 14,
                        height: 1.4,
                        fontWeight:
                            headline == null ? FontWeight.w500 : FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
