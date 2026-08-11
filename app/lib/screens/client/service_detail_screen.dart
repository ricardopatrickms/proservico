import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/service_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../../widgets/service_cards.dart';

class ServiceDetailScreen extends StatelessWidget {
  final ServiceRequest request;

  const ServiceDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final photoUrls = request.photoUrls
        .map(ApiConfig.resolveStorageUrl)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe do serviço')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          UrgencyBadge(urgency: request.urgency),
          const SizedBox(height: 16),
          _InfoTile(icon: Icons.description_outlined, label: 'Descrição', value: request.description),
          _InfoTile(icon: Icons.place_outlined, label: 'Localização', value: request.location),
          _InfoTile(icon: Icons.schedule, label: 'Data e horário', value: formatDate(request.scheduledAt)),
          if (request.budget != null)
            _InfoTile(icon: Icons.attach_money, label: 'Orçamento', value: formatCurrency(request.budget!)),
          _InfoTile(
            icon: Icons.inventory_2_outlined,
            label: 'Materiais',
            value: request.needsMaterials ? 'Cliente solicita materiais' : 'Não precisa de materiais',
          ),
          if (request.preferences.isNotEmpty)
            _InfoTile(icon: Icons.tune, label: 'Preferências', value: request.preferences),
          if (request.professionalName != null)
            _InfoTile(icon: Icons.engineering_outlined, label: 'Profissional', value: request.professionalName!),
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photoUrls[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 120,
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (request.photoLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: request.photoLabels
                  .map(
                    (p) => Chip(
                      avatar: const Icon(Icons.image_outlined, size: 18),
                      label: Text(p),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
