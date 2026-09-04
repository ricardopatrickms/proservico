import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../services/session_store.dart';
import '../../theme/app_theme.dart';
import '../client/service_detail_screen.dart';
import 'professional_placeholder_screen.dart';
import 'professional_request_detail_sheet.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  const ProfessionalDashboardScreen({super.key});

  @override
  State<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends State<ProfessionalDashboardScreen> {
  final _service = ServiceRequestService.instance;

  List<ServiceRequest> _requests = [];
  bool _loading = true;
  String? _error;

  String? get _userId => SessionStore.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _service.list();
      if (!mounted) return;
      setState(() {
        _requests = all;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.displayMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o painel.';
        _loading = false;
      });
    }
  }

  List<ServiceRequest> get _active => _requests
      .where((r) => r.status == ServiceStatus.inProgress)
      .toList();

  List<ServiceRequest> get _availablePending {
    final userId = _userId;
    return _requests.where((r) {
      if (r.status != ServiceStatus.pending) return false;
      if (userId == null) return true;
      return !r.proposals.any((p) => p.professionalId == userId);
    }).toList();
  }

  List<ServiceRequest> get _completed => _requests
      .where((r) => r.status == ServiceStatus.completed)
      .toList();

  double _serviceValue(ServiceRequest request) {
    final userId = _userId;
    if (userId != null) {
      final accepted = request.proposals.where(
        (p) =>
            p.professionalId == userId && p.status == ProposalStatus.accepted,
      );
      if (accepted.isNotEmpty) return accepted.first.amount;

      final mine = request.proposals.where((p) => p.professionalId == userId);
      if (mine.isNotEmpty) return mine.first.amount;
    }
    return request.budget ?? request.budgetMax ?? request.budgetMin ?? 0;
  }

  double _earningsInMonth(DateTime month) {
    return _completed
        .where(
          (r) =>
              r.scheduledAt.year == month.year &&
              r.scheduledAt.month == month.month,
        )
        .fold<double>(0, (sum, r) => sum + _serviceValue(r));
  }

  String _money(double value) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: value == value.roundToDouble() ? 0 : 2,
    ).format(value);
  }

  String _place(ServiceRequest request) {
    final city = request.city?.trim();
    if (city != null && city.isNotEmpty) return city;
    return request.location;
  }

  List<_ActivityItem> get _recentActivity {
    final items = <_ActivityItem>[];

    final newestPending = [..._availablePending]
      ..sort(
        (a, b) => (b.createdAt ?? b.scheduledAt)
            .compareTo(a.createdAt ?? a.scheduledAt),
      );
    for (final r in newestPending.take(2)) {
      items.add(
        _ActivityItem(
          request: r,
          title: 'Novo pedido recebido',
          subtitle: '${r.title} - ${_place(r)}',
          badge: 'Novo',
          badgeColor: const Color(0xFF1E3A5F),
          badgeTextColor: Colors.white,
          background: const Color(0xFFEFF6FF),
        ),
      );
    }

    final newestCompleted = [..._completed]
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    for (final r in newestCompleted.take(2)) {
      items.add(
        _ActivityItem(
          request: r,
          title: 'Serviço finalizado',
          subtitle: '${r.title} - ${_place(r)}',
          badge: 'Concluído',
          badgeColor: const Color(0xFFD1FAE5),
          badgeTextColor: const Color(0xFF065F46),
          background: const Color(0xFFECFDF5),
        ),
      );
    }

    final myPendingProposals = _requests.where((r) {
      final userId = _userId;
      if (userId == null) return false;
      return r.status == ServiceStatus.pending &&
          r.proposals.any(
            (p) =>
                p.professionalId == userId &&
                p.status == ProposalStatus.pending,
          );
    }).toList()
      ..sort(
        (a, b) => (b.createdAt ?? b.scheduledAt)
            .compareTo(a.createdAt ?? a.scheduledAt),
      );

    for (final r in myPendingProposals.take(1)) {
      items.add(
        _ActivityItem(
          request: r,
          title: 'Proposta enviada',
          subtitle: '${r.title} - aguardando resposta do cliente',
          badge: 'Proposta',
          badgeColor: const Color(0xFFDBEAFE),
          badgeTextColor: const Color(0xFF1E40AF),
          background: const Color(0xFFFFFBEB),
        ),
      );
    }

    return items.take(3).toList();
  }

  List<ServiceRequest> get _upcoming {
    final now = DateTime.now();
    final list = _active.where((r) => !r.scheduledAt.isBefore(
          DateTime(now.year, now.month, now.day),
        )).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (list.isNotEmpty) return list.take(3).toList();

    final fallback = [..._active]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return fallback.take(3).toList();
  }

  String _whenLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final time = DateFormat('HH:mm', 'pt_BR').format(date);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hoje, $time';
    if (diff == 1) return 'Amanhã, $time';
    final weekday = DateFormat('EEEE', 'pt_BR').format(date);
    final capped = weekday.isEmpty
        ? DateFormat('dd/MM', 'pt_BR').format(date)
        : '${weekday[0].toUpperCase()}${weekday.substring(1)}';
    return '$capped, $time';
  }

  Future<void> _openRequest(ServiceRequest request) async {
    if (request.status == ServiceStatus.pending) {
      await showProfessionalRequestDetail(context, request);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.instance.currentUser;
    final firstName = (user?.name.trim().isNotEmpty == true)
        ? user!.name.trim().split(RegExp(r'\s+')).first
        : 'profissional';

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    final earnings = _earningsInMonth(thisMonth);
    final previous = _earningsInMonth(lastMonth);
    final earningsSubtitle = () {
      if (previous <= 0 && earnings <= 0) {
        return 'Nenhum serviço concluído neste mês';
      }
      if (previous <= 0) {
        return 'Serviços concluídos neste mês';
      }
      final delta = ((earnings - previous) / previous) * 100;
      final sign = delta >= 0 ? '+' : '';
      return '$sign${delta.toStringAsFixed(0)}% em relação ao mês anterior';
    }();

    return ProfessionalPageScaffold(
      title: 'Olá, $firstName! 👋',
      subtitle: 'Bem-vindo ao seu painel profissional',
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (user != null && !user.approved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
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
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _ErrorCard(message: _error!, onRetry: _load)
                else ...[
                  _StatsRow(
                    wide: wide,
                    activeCount: _active.length,
                    earningsLabel: _money(earnings),
                    earningsSubtitle: earningsSubtitle,
                    earningsPositive: earnings >= previous,
                    newOrdersCount: _availablePending.length,
                  ),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RecentActivityCard(
                            items: _recentActivity,
                            onTap: _openRequest,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _UpcomingCard(
                            requests: _upcoming,
                            whenLabel: _whenLabel,
                            placeLabel: _place,
                            onTap: _openRequest,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _RecentActivityCard(
                      items: _recentActivity,
                      onTap: _openRequest,
                    ),
                    const SizedBox(height: 16),
                    _UpcomingCard(
                      requests: _upcoming,
                      whenLabel: _whenLabel,
                      placeLabel: _place,
                      onTap: _openRequest,
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityItem {
  final ServiceRequest request;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color background;

  const _ActivityItem({
    required this.request,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.background,
  });
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final bool wide;
  final int activeCount;
  final String earningsLabel;
  final String earningsSubtitle;
  final bool earningsPositive;
  final int newOrdersCount;

  const _StatsRow({
    required this.wide,
    required this.activeCount,
    required this.earningsLabel,
    required this.earningsSubtitle,
    required this.earningsPositive,
    required this.newOrdersCount,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashStatCard(
        label: 'Serviços Ativos',
        value: '$activeCount',
        subtitle: activeCount == 0
            ? 'Nenhum serviço em andamento'
            : 'Em andamento e agendados',
        icon: Icons.work_outline,
        iconColor: AppColors.primary,
      ),
      _DashStatCard(
        label: 'Ganhos do Mês',
        value: earningsLabel,
        subtitle: earningsSubtitle,
        subtitleColor: earningsPositive ? AppColors.success : AppColors.danger,
        icon: Icons.attach_money,
        iconColor: AppColors.success,
      ),
      _DashStatCard(
        label: 'Novos Pedidos',
        value: '$newOrdersCount',
        subtitle: newOrdersCount == 0
            ? 'Nenhum pedido disponível'
            : 'Aguardando sua proposta',
        icon: Icons.notifications_outlined,
        iconColor: AppColors.warning,
      ),
      const _DashStatCard(
        label: 'Avaliação Média',
        value: '—',
        subtitle: 'Em breve',
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
              fontWeight:
                  subtitleColor != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<_ActivityItem> items;
  final ValueChanged<ServiceRequest> onTap;

  const _RecentActivityCard({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Atividade Recente',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma atividade recente.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  InkWell(
                    onTap: () => onTap(items[i].request),
                    borderRadius: BorderRadius.circular(10),
                    child: _ActivityRow(
                      background: items[i].background,
                      title: items[i].title,
                      subtitle: items[i].subtitle,
                      badge: items[i].badge,
                      badgeColor: items[i].badgeColor,
                      badgeTextColor: items[i].badgeTextColor,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final List<ServiceRequest> requests;
  final String Function(DateTime) whenLabel;
  final String Function(ServiceRequest) placeLabel;
  final ValueChanged<ServiceRequest> onTap;

  const _UpcomingCard({
    required this.requests,
    required this.whenLabel,
    required this.placeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Próximos Compromissos',
      child: requests.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum compromisso agendado.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < requests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  InkWell(
                    onTap: () => onTap(requests[i]),
                    borderRadius: BorderRadius.circular(10),
                    child: _ScheduleRow(
                      when: whenLabel(requests[i].scheduledAt),
                      what: '${requests[i].title} - ${placeLabel(requests[i])}',
                    ),
                  ),
                ],
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
            child: const Icon(
              Icons.access_time,
              size: 18,
              color: AppColors.primary,
            ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
