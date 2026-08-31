import 'package:flutter/material.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/professional_service_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import '../../widgets/service_category_picker.dart';

class ServiceFormScreen extends StatefulWidget {
  final ProfessionalService? service;

  const ServiceFormScreen({super.key, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ProfessionalServiceService.instance;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  String? _category;
  late bool _active;
  bool _saving = false;

  bool get _isEditing => widget.service != null;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _titleController = TextEditingController(text: service?.title ?? '');
    _category = service?.category;
    _descriptionController = TextEditingController(text: service?.description ?? '');
    _priceController = TextEditingController(
      text: service != null ? service.priceFrom.toStringAsFixed(2) : '',
    );
    _active = service?.active ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final category = _category?.trim() ?? '';
    if (category.isEmpty) return;

    final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _api.update(
          widget.service!.id,
          title: _titleController.text.trim(),
          category: category,
          description: _descriptionController.text.trim(),
          priceFrom: price,
          active: _active,
        );
        if (!mounted) return;
        showAppSnackBar(context, 'Serviço atualizado');
      } else {
        await _api.create(
          title: _titleController.text.trim(),
          category: category,
          description: _descriptionController.text.trim(),
          priceFrom: price,
          active: _active,
        );
        if (!mounted) return;
        showAppSnackBar(context, 'Serviço cadastrado');
      }
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível salvar o serviço.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar serviço' : 'Cadastrar serviço')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            ServiceCategoryPicker(
              value: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preço a partir de (R\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Obrigatório';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                return null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Serviço ativo'),
              subtitle: const Text('Visível para clientes'),
              value: _active,
              onChanged: _saving ? null : (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Salvar alterações' : 'Cadastrar'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gestão de propostas, chat e avaliações ficam para módulos futuros.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
