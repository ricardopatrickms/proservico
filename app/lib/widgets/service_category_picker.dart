import 'package:flutter/material.dart';

import '../models/service_category.dart';
import '../services/api_exception.dart';
import '../services/service_category_service.dart';
import '../theme/app_theme.dart';

class ServiceCategoryPicker extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final String hintText;
  final Widget? prefixIcon;
  final bool keepUnknownValue;

  const ServiceCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.hintText = 'Selecione a categoria',
    this.prefixIcon,
    this.keepUnknownValue = true,
  });

  @override
  State<ServiceCategoryPicker> createState() => _ServiceCategoryPickerState();
}

class _ServiceCategoryPickerState extends State<ServiceCategoryPicker> {
  List<ServiceCategory> _roots = [];
  bool _loading = true;
  String? _error;

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
      final roots = await ServiceCategoryService.instance.list();
      if (!mounted) return;
      setState(() {
        _roots = roots;
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
        _error = 'Não foi possível carregar as categorias.';
        _loading = false;
      });
    }
  }

  List<DropdownMenuItem<String>> _items() {
    final items = <DropdownMenuItem<String>>[];
    final names = <String>{};

    for (final root in _roots) {
      if (root.hasChildren) {
        items.add(
          DropdownMenuItem<String>(
            enabled: false,
            value: '__group_${root.id}',
            child: Text(
              root.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
        for (final child in root.children) {
          if (child.name.isEmpty || names.contains(child.name)) continue;
          names.add(child.name);
          items.add(
            DropdownMenuItem<String>(
              value: child.name,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(child.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          );
        }
      } else if (root.name.isNotEmpty && names.add(root.name)) {
        items.add(
          DropdownMenuItem<String>(
            value: root.name,
            child: Text(root.name, overflow: TextOverflow.ellipsis),
          ),
        );
      }
    }

    final extra = widget.value?.trim() ?? '';
    if (widget.keepUnknownValue && extra.isNotEmpty && !names.contains(extra)) {
      items.insert(
        0,
        DropdownMenuItem<String>(
          value: extra,
          child: Text(extra, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              errorText: _error,
            ),
            child: Text(
              'Falha ao carregar categorias',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }

    final items = _loading ? const <DropdownMenuItem<String>>[] : _items();
    final names = items
        .where((i) => i.enabled && i.value != null)
        .map((i) => i.value!)
        .toSet();
    final value =
        widget.value != null && names.contains(widget.value) ? widget.value : null;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(
        hintText: _loading ? 'Carregando categorias...' : widget.hintText,
        prefixIcon: widget.prefixIcon,
      ),
      items: items,
      onChanged: (!widget.enabled || _loading) ? null : widget.onChanged,
      validator: (v) {
        if (_loading) return 'Aguarde o carregamento das categorias';
        if (widget.validator != null) return widget.validator!(v);
        return v == null ? 'Selecione a categoria' : null;
      },
    );
  }
}
