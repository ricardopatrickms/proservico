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
    return _ProfessionalPageScaffold(
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

/// Layout comum das páginas do painel (sem AppBar no desktop).
class ProfessionalPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget>? actions;

  const ProfessionalPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfessionalPageScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      child: child,
    );
  }
}

class _ProfessionalPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget>? actions;

  const _ProfessionalPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
