import 'package:flutter/material.dart';

import '../models/service_request.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final ServiceStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ServiceStatus.pending => ('Pendente', AppColors.warning),
      ServiceStatus.inProgress => ('Em andamento', AppColors.primary),
      ServiceStatus.completed => ('Concluído', AppColors.success),
      ServiceStatus.cancelled => ('Cancelado', AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class UrgencyBadge extends StatelessWidget {
  final ServiceUrgency urgency;

  const UrgencyBadge({super.key, required this.urgency});

  @override
  Widget build(BuildContext context) {
    if (urgency == ServiceUrgency.normal) {
      return const SizedBox.shrink();
    }
    final label = urgency == ServiceUrgency.emergency ? 'Emergência' : 'Urgente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ServiceRequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback? onTap;

  const ServiceRequestCard({super.key, required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: StatusBadge(status: request.status)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  UrgencyBadge(urgency: request.urgency),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
