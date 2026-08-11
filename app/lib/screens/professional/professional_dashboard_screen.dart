import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../theme/app_theme.dart';
import 'professional_placeholder_screen.dart';

class ProfessionalDashboardScreen extends StatelessWidget {
  const ProfessionalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockStore.instance.currentUser;
    final firstName = (user?.name.trim().isNotEmpty == true)
        ? user!.name.trim().split(RegExp(r'\s+')).first
        : 'profissional';

    return ProfessionalPageScaffold(
      title: 'Olá, $firstName! 👋',
      subtitle: 'Bem-vindo ao seu painel profissional',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (user != null && !user.approved)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top, color: AppColors.warning),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Seu cadastro aguarda aprovação do administrador.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              _StatsRow(wide: wide),
              const SizedBox(height: 20),
              if (wide)
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _RecentActivityCard()),
                    SizedBox(width: 16),
                    Expanded(child: _UpcomingCard()),
                  ],
                )
              else ...[
                const _RecentActivityCard(),
                const SizedBox(height: 16),
                const _UpcomingCard(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final bool wide;

  const _StatsRow({required this.wide});

  @override
  Widget build(BuildContext context) {
    final cards = const [
      _DashStatCard(
        label: 'Serviços Ativos',
        value: '3',
        subtitle: 'Em andamento e agendados',
        icon: Icons.work_outline,
        iconColor: AppColors.primary,
      ),
      _DashStatCard(
        label: 'Ganhos do Mês',
        value: 'R\$ 2.850',
        subtitle: '+12% em relação ao mês anterior',
        subtitleColor: AppColors.success,
        icon: Icons.attach_money,
        iconColor: AppColors.success,
      ),
      _DashStatCard(
        label: 'Novos Pedidos',
        value: '1',
        subtitle: 'Aguardando sua resposta',
        icon: Icons.notifications_outlined,
        iconColor: AppColors.warning,
      ),
      _DashStatCard(
        label: 'Avaliação Média',
        value: '4.8',
        subtitle: 'Baseado em 47 avaliações',
        icon: Icons.star_outline,
        iconColor: Color(0xFFF59E0B),
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _DashStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? subtitleColor;

  const _DashStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: subtitleColor ?? AppColors.textSecondary,
              fontWeight: subtitleColor != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Atividade Recente',
      child: Column(
        children: const [
          _ActivityRow(
            background: Color(0xFFEFF6FF),
            title: 'Novo pedido recebido',
            subtitle: 'Reparo elétrico - Jardim dos Estados',
            badge: 'Novo',
            badgeColor: Color(0xFF1E3A5F),
            badgeTextColor: Colors.white,
          ),
          SizedBox(height: 10),
          _ActivityRow(
            background: Color(0xFFECFDF5),
            title: 'Serviço finalizado',
            subtitle: 'Instalação de chuveiro - Centro',
            badge: 'Concluído',
            badgeColor: Color(0xFFD1FAE5),
            badgeTextColor: Color(0xFF065F46),
          ),
          SizedBox(height: 10),
          _ActivityRow(
            background: Color(0xFFFFFBEB),
            title: 'Mensagem do cliente',
            subtitle: 'Maria Silva - Dúvida sobre o orçamento',
            badge: 'Mensagem',
            badgeColor: Color(0xFFDBEAFE),
            badgeTextColor: Color(0xFF1E40AF),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Próximos Compromissos',
      child: Column(
        children: const [
          _ScheduleRow(when: 'Hoje, 14:00', what: 'Instalação de tomadas - Vila Carvalho'),
          SizedBox(height: 10),
          _ScheduleRow(when: 'Amanhã, 09:00', what: 'Troca de disjuntor - Centro'),
          SizedBox(height: 10),
          _ScheduleRow(when: 'Sexta, 16:00', what: 'Manutenção elétrica - Jardim dos Estados'),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PanelCard({required this.title, required this.child});

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Color background;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;

  const _ActivityRow({
    required this.background,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String when;
  final String what;

  const _ScheduleRow({required this.when, required this.what});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  what,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
