import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'professional_placeholder_screen.dart';

class ProfessionalHistoryScreen extends StatefulWidget {
  const ProfessionalHistoryScreen({super.key});

  @override
  State<ProfessionalHistoryScreen> createState() => _ProfessionalHistoryScreenState();
}

class _ProfessionalHistoryScreenState extends State<ProfessionalHistoryScreen> {
  final _searchController = TextEditingController();
  String _status = 'Todos os Status';

  final _statusOptions = const [
    'Todos os Status',
    'Concluído',
    'Cancelado',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalPageScaffold(
      title: 'Histórico de Serviços',
      subtitle: 'Todos os seus serviços concluídos',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 560;
                final search = TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar serviços...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                );
                final filter = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      isExpanded: true,
                      icon: const Icon(Icons.filter_list, size: 20),
                      items: _statusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _status = v);
                      },
                    ),
                  ),
                );

                if (stack) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      filter,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 200, child: filter),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Nenhum serviço encontrado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tente ajustar os filtros de busca',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Estatísticas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: _HistoryStat(
                    value: '0',
                    label: 'Serviços Concluídos',
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _HistoryStat(
                    value: 'R\$ 4.250',
                    label: 'Total Faturado',
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _HistoryStat(
                    value: '4.8',
                    label: 'Nota Média',
                    color: Color(0xFFF59E0B),
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

class _HistoryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HistoryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
