import 'package:flutter/material.dart';

import '../models/service_category.dart';
import '../services/api_exception.dart';
import '../services/service_category_service.dart';
import '../theme/app_theme.dart';
import 'helpers.dart';

/// Seleção de várias categorias raiz do catálogo, exibidas como etiquetas removíveis.
class ServiceCategoriesField extends StatefulWidget {
  final List<ServiceCategory> value;
  final ValueChanged<List<ServiceCategory>> onChanged;
  final String? Function(List<ServiceCategory>)? validator;

  const ServiceCategoriesField({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  State<ServiceCategoriesField> createState() => _ServiceCategoriesFieldState();
}

class _ServiceCategoriesFieldState extends State<ServiceCategoriesField> {
  static const _labelStyle = TextStyle(fontSize: 12, color: AppColors.textPrimary);
  static const _labelPadding = EdgeInsets.symmetric(horizontal: 4);
  static const _padding = EdgeInsets.symmetric(horizontal: 4);

  bool _loading = false;

  Future<void> _add(FormFieldState<List<ServiceCategory>> field) async {
    if (_loading) return;
    setState(() => _loading = true);

    var catalog = <ServiceCategory>[];
    try {
      catalog = await ServiceCategoryService.instance.list();
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.displayMessage);
      return;
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Não foi possível carregar as categorias.');
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;

    final selectedIds = widget.value.map((c) => c.id).toSet();
    final available = catalog.where((c) => !selectedIds.contains(c.id)).toList();
    if (available.isEmpty) {
      showAppSnackBar(context, 'Você já adicionou todas as categorias disponíveis.');
      return;
    }

    final picked = await showModalBottomSheet<ServiceCategory>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Adicionar categoria',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final c in available)
                      ListTile(
                        leading: const Icon(Icons.category_outlined, color: AppColors.primary),
                        title: Text(c.name),
                        onTap: () => Navigator.pop(context, c),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _update(field, [...widget.value, picked]);
  }

  void _update(
    FormFieldState<List<ServiceCategory>> field,
    List<ServiceCategory> next,
  ) {
    widget.onChanged(next);
    field.didChange(next);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<ServiceCategory>>(
      initialValue: widget.value,
      validator: widget.validator == null ? null : (_) => widget.validator!(widget.value),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in widget.value)
                InputChip(
                  label: Text(c.name),
                  labelStyle: _labelStyle,
                  labelPadding: _labelPadding,
                  padding: _padding,
                  deleteIcon: const Icon(Icons.close, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => _update(
                    field,
                    widget.value.where((v) => v.id != c.id).toList(),
                  ),
                ),
              ActionChip(
                avatar: _loading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 14),
                label: const Text('Adicionar'),
                labelStyle: _labelStyle,
                labelPadding: _labelPadding,
                padding: _padding,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : () => _add(field),
              ),
            ],
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                field.errorText!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
