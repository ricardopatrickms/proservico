import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppMenuItem {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool danger;

  const AppMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.danger = false,
  });
}

/// Tela de menu em estilo app nativo (lista full-screen com chevron).
class AppMenuScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<AppMenuItem> items;
  final List<AppMenuItem> footerItems;

  const AppMenuScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.footerItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            for (final item in items) ...[
              _MenuTile(item: item),
              const SizedBox(height: 12),
            ],
            if (footerItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 20),
              for (final item in footerItems) ...[
                _MenuTile(item: item),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final AppMenuItem item;

  const _MenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.danger ? AppColors.danger : AppColors.primary;
    final border = item.danger
        ? AppColors.danger.withValues(alpha: 0.35)
        : AppColors.border;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 22, color: accent),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: item.danger ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
