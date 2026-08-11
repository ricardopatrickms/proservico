import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import 'professional_placeholder_screen.dart';

class ProfessionalSettingsScreen extends StatefulWidget {
  const ProfessionalSettingsScreen({super.key});

  @override
  State<ProfessionalSettingsScreen> createState() => _ProfessionalSettingsScreenState();
}

class _ProfessionalSettingsScreenState extends State<ProfessionalSettingsScreen> {
  bool _push = true;
  bool _email = true;
  bool _sms = false;
  bool _marketing = false;
  bool _location = true;
  String _language = 'Português (Brasil)';

  @override
  Widget build(BuildContext context) {
    return ProfessionalPageScaffold(
      title: 'Configurações',
      subtitle: 'Personalize sua experiência no ProServiço',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _SettingsCard(
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            child: Column(
              children: [
                _ToggleRow(
                  title: 'Notificações Push',
                  subtitle: 'Receba alertas no seu dispositivo',
                  value: _push,
                  onChanged: (v) => setState(() => _push = v),
                ),
                const Divider(height: 20),
                _ToggleRow(
                  title: 'E-mail',
                  subtitle: 'Receba atualizações por e-mail',
                  value: _email,
                  onChanged: (v) => setState(() => _email = v),
                ),
                const Divider(height: 20),
                _ToggleRow(
                  title: 'SMS',
                  subtitle: 'Receba confirmações por SMS',
                  value: _sms,
                  onChanged: (v) => setState(() => _sms = v),
                ),
                const Divider(height: 20),
                _ToggleRow(
                  title: 'Marketing',
                  subtitle: 'Receba ofertas e promoções',
                  value: _marketing,
                  onChanged: (v) => setState(() => _marketing = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            icon: Icons.place_outlined,
            title: 'Localização',
            child: _ToggleRow(
              title: 'Permitir Localização',
              subtitle: 'Ajuda a encontrar profissionais próximos a você',
              value: _location,
              onChanged: (v) => setState(() => _location = v),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            icon: Icons.language,
            title: 'Idioma',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Idioma do Aplicativo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _language,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Português (Brasil)',
                          child: Text('Português (Brasil)'),
                        ),
                        DropdownMenuItem(
                          value: 'English (US)',
                          child: Text('English (US)'),
                        ),
                        DropdownMenuItem(
                          value: 'Español',
                          child: Text('Español'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _language = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacidade e Dados',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dados Pessoais', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Gerencie como seus dados são utilizados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAppSnackBar(context, 'Disponível em breve'),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Histórico de Serviços', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'Seus dados de serviços são mantidos para melhorar a experiência',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAppSnackBar(context, 'Disponível em breve'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
