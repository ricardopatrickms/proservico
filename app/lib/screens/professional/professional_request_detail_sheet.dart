import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/api_config.dart';
import '../../models/service_request.dart';
import '../../theme/app_theme.dart';

Future<void> showProfessionalRequestDetail(
  BuildContext context,
  ServiceRequest request,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ProfessionalRequestDetailSheet(request: request),
  );
}

class ProfessionalRequestDetailSheet extends StatelessWidget {
  final ServiceRequest request;

  const ProfessionalRequestDetailSheet({super.key, required this.request});

  String get _urgencyLabel {
    return switch (request.urgency) {
      ServiceUrgency.urgent => 'Urgente (até 48h)',
      ServiceUrgency.emergency => 'Emergência',
      ServiceUrgency.normal => 'Normal',
    };
  }

  Color get _urgencyBg {
    return switch (request.urgency) {
      ServiceUrgency.normal => const Color(0xFFF3F4F6),
      _ => const Color(0xFFFEE2E2),
    };
  }

  Color get _urgencyFg {
    return switch (request.urgency) {
      ServiceUrgency.normal => AppColors.textSecondary,
      _ => AppColors.danger,
    };
  }

  String get _materialsLabel {
    return switch (request.materialsResponsible) {
      'client' => 'Cliente fornece o material',
      'professional' => 'Profissional fornece o material',
      'shared' => 'Responsabilidade compartilhada',
      _ => request.needsMaterials
          ? 'Cliente solicita materiais'
          : 'Não precisa de materiais',
    };
  }

  String get _cityState {
    final parts = [
      if (request.city != null && request.city!.trim().isNotEmpty)
        request.city!.trim(),
      if (request.state != null && request.state!.trim().isNotEmpty)
        request.state!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return request.location;
  }

  String? get _budgetLabel {
    if (request.budgetMin != null && request.budgetMax != null) {
      return '${_money(request.budgetMin!)} - ${_money(request.budgetMax!)}';
    }
    if (request.budgetMax != null) return _money(request.budgetMax!);
    if (request.budgetMin != null) return _money(request.budgetMin!);
    if (request.budget != null) return _money(request.budget!);
    return null;
  }

  static String _money(double v) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  }

  String get _dateLabel {
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(request.scheduledAt);
  }

  String get _periodLabel {
    final period = request.preferredPeriod;
    if (period == null) return 'A combinar';
    return '${period.label} (${period.subtitle})';
  }

  IconData get _periodIcon {
    return switch (request.preferredPeriod) {
      PreferredPeriod.morning => Icons.wb_sunny_outlined,
      PreferredPeriod.afternoon => Icons.wb_twilight_outlined,
      PreferredPeriod.evening => Icons.nightlight_round,
      PreferredPeriod.business => Icons.business_center_outlined,
      null => Icons.schedule,
    };
  }

  @override
  Widget build(BuildContext context) {
    final photos = request.photoUrls
        .map(ApiConfig.resolveStorageUrl)
        .toList();
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (request.category != null &&
                          request.category!.isNotEmpty)
                        _Badge(
                          label: request.category!,
                          background: const Color(0xFFEFF6FF),
                          foreground: AppColors.primaryDark,
                        ),
                      _Badge(
                        label: _urgencyLabel,
                        background: _urgencyBg,
                        foreground: _urgencyFg,
                        icon: request.urgency == ServiceUrgency.normal
                            ? null
                            : Icons.bolt,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                request.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SectionTitle(
                  icon: Icons.description_outlined,
                  title: 'Descrição do Serviço',
                ),
                const SizedBox(height: 8),
                _Box(
                  child: Text(
                    request.description.isEmpty
                        ? 'Sem descrição'
                        : request.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (photos.isNotEmpty || request.photoLabels.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(
                    icon: Icons.photo_camera_outlined,
                    title:
                        'Fotos do Problema (${photos.isNotEmpty ? photos.length : request.photoLabels.length})',
                  ),
                  const SizedBox(height: 10),
                  if (photos.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            photos[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.background,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: request.photoLabels
                          .map(
                            (label) => Chip(
                              avatar: const Icon(Icons.image_outlined, size: 16),
                              label: Text(label, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                    ),
                ],
                const SizedBox(height: 20),
                const _SectionTitle(
                  icon: Icons.place_outlined,
                  title: 'Localização',
                ),
                const SizedBox(height: 8),
                _Box(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabeledValue(
                        label: 'Endereço',
                        value: (request.address?.trim().isNotEmpty == true)
                            ? request.address!
                            : '—',
                      ),
                      const SizedBox(height: 10),
                      _LabeledValue(label: 'Cidade', value: _cityState),
                      if (request.referencePoint != null &&
                          request.referencePoint!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _LabeledValue(
                          label: 'Ponto de Referência',
                          value: request.referencePoint!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle(
                  icon: Icons.calendar_today_outlined,
                  title: 'Data Preferida',
                ),
                const SizedBox(height: 8),
                _Box(
                  child: Text(
                    _dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(
                  icon: Icons.access_time,
                  title: 'Horário',
                ),
                const SizedBox(height: 8),
                _Box(
                  child: Row(
                    children: [
                      Icon(
                        _periodIcon,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _periodLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_budgetLabel != null) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    icon: Icons.attach_money,
                    title: 'Faixa de Preço',
                  ),
                  const SizedBox(height: 8),
                  _Box(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _budgetLabel!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (request.acceptsNegotiation) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 15,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Cliente aberto a negociação',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionTitle(
                  icon: Icons.inventory_2_outlined,
                  title: 'Responsabilidade pelo Material',
                ),
                const SizedBox(height: 8),
                _Box(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _materialsLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (request.materialsDetails != null &&
                          request.materialsDetails!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Detalhes: ${request.materialsDetails}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  final Widget child;

  const _Box({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _LabeledValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
