import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import 'service_detail_screen.dart';

class RequestServiceScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;

  const RequestServiceScreen({super.key, this.onSubmitted});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _cepController = TextEditingController();
  final _referenceController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _materialsDetailsController = TextEditingController();

  String? _category;
  DateTime? _preferredDate;
  PreferredPeriod? _period;
  bool _acceptsNegotiation = true;
  String? _materialsResponsible;
  ServiceUrgency _urgency = ServiceUrgency.normal;
  bool _prefersGoodRatings = true;
  GenderPreference _genderPreference = GenderPreference.any;
  final List<XFile> _photos = [];
  bool _loading = false;

  static const _categories = [
    'Elétrica',
    'Hidráulica',
    'Climatização',
    'Pintura',
    'Limpeza',
    'Jardinagem',
    'Marcenaria',
    'Alvenaria',
    'Informática',
    'Outros',
  ];

  static const _materialsOptions = <(String, String)>[
    ('client', 'Cliente fornece os materiais'),
    ('professional', 'Profissional fornece os materiais'),
    ('shared', 'A combinar / compartilhar'),
  ];

  static const _maxPhotoBytes = 5 * 1024 * 1024;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _cepController.dispose();
    _referenceController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _materialsDetailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (date == null || !mounted) return;
    setState(() => _preferredDate = date);
  }

  Future<ImageSource?> _askPhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Como deseja enviar a foto?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                  title: const Text('Câmera'),
                  subtitle: const Text('Tirar uma foto agora'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
                  title: const Text('Galeria'),
                  subtitle: const Text('Selecionar imagem da galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 8) {
      showAppSnackBar(context, 'Limite de 8 fotos por solicitação');
      return;
    }

    final source = await _askPhotoSource();
    if (source == null || !mounted) return;

    // Evita conflito de Activity ao fechar o bottom sheet no Android.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image == null || !mounted) return;

      final bytes = await image.length();
      if (!mounted) return;
      if (bytes > _maxPhotoBytes) {
        showAppSnackBar(context, 'Cada foto deve ter no máximo 5 MB');
        return;
      }

      setState(() => _photos.add(image));
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível adicionar a foto.');
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photos.length < 2) {
      showAppSnackBar(context, 'Você precisa enviar no mínimo 2 fotos para continuar');
      return;
    }
    if (_preferredDate == null) {
      showAppSnackBar(context, 'Selecione a data preferida');
      return;
    }
    if (_period == null) {
      showAppSnackBar(context, 'Selecione o período preferido');
      return;
    }
    if (_loading) return;

    final budgetMin = _budgetMinController.text.trim().isEmpty
        ? null
        : double.tryParse(_budgetMinController.text.replaceAll(',', '.'));
    final budgetMax = _budgetMaxController.text.trim().isEmpty
        ? null
        : double.tryParse(_budgetMaxController.text.replaceAll(',', '.'));

    if (budgetMin != null && budgetMax != null && budgetMin > budgetMax) {
      showAppSnackBar(context, 'O valor mínimo não pode ser maior que o máximo');
      return;
    }

    setState(() => _loading = true);
    try {
      final created = await ClientRequestsStore.instance.create(
        CreateServiceRequestInput(
          title: _titleController.text.trim(),
          category: _category!,
          description: _descriptionController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim().toUpperCase(),
          cep: _cepController.text.trim(),
          referencePoint: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          preferredDate: _preferredDate!,
          preferredPeriod: _period!,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          acceptsNegotiation: _acceptsNegotiation,
          materialsResponsible: _materialsResponsible!,
          materialsDetails: _materialsDetailsController.text.trim().isEmpty
              ? null
              : _materialsDetailsController.text.trim(),
          urgency: _urgency,
          prefersGoodRatings: _prefersGoodRatings,
          genderPreference: _genderPreference,
          photoPaths: _photos.map((p) => p.path).toList(),
        ),
      );

      if (!mounted) return;
      _resetForm();
      await showSuccessDialog(
        context: context,
        title: 'Solicitação enviada!',
        message:
            'Seu pedido foi cadastrado com sucesso. Veja os detalhes do serviço.',
        buttonLabel: 'Ver meu serviço',
      );
      if (!mounted) return;
      widget.onSubmitted?.call();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(request: created),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível enviar a solicitação.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _addressController.clear();
    _cityController.clear();
    _stateController.clear();
    _cepController.clear();
    _referenceController.clear();
    _budgetMinController.clear();
    _budgetMaxController.clear();
    _materialsDetailsController.clear();
    setState(() {
      _category = null;
      _preferredDate = null;
      _period = null;
      _acceptsNegotiation = true;
      _materialsResponsible = null;
      _urgency = ServiceUrgency.normal;
      _prefersGoodRatings = true;
      _genderPreference = GenderPreference.any;
      _photos.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Solicitar Serviço'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _loading ? null : _submit,
              child: const Text('Solicitar Serviço'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text(
              'Encontre o profissional ideal',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Preencha os detalhes para receber propostas de profissionais qualificados.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              number: 1,
              title: 'Qual serviço você precisa?',
              color: AppColors.primary,
              icon: Icons.handyman_outlined,
              children: [
                _label('Categoria do serviço'),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    hintText: 'Selecione a categoria',
                    prefixIcon: Icon(Icons.lightbulb_outline),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? 'Selecione a categoria' : null,
                ),
                const SizedBox(height: 14),
                _label('Título do Serviço'),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Troca de tomada na sala',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
                ),
                const SizedBox(height: 14),
                _label('Descrição Detalhada'),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Descreva o problema ou o serviço desejado',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: 14),
                _label('Fotos do Problema'),
                InkWell(
                  onTap: _loading ? null : _addPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                        width: 1.4,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'Toque para adicionar fotos',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'JPG, PNG ou WEBP (máx. 5 MB)',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(photo.path),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() => _photos.removeAt(index)),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Você precisa enviar no mínimo 2 fotos para continuar',
                  style: TextStyle(
                    color: _photos.length < 2 ? AppColors.danger : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            _SectionCard(
              number: 2,
              title: 'Onde será realizado?',
              color: const Color(0xFF16A34A),
              icon: Icons.place_outlined,
              children: [
                _label('Endereço Completo'),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: 'Rua, número e bairro',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o endereço' : null,
                ),
                const SizedBox(height: 14),
                _label('Cidade'),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(hintText: 'Cidade'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe a cidade' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Estado'),
                          TextFormField(
                            controller: _stateController,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 2,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'UF',
                              counterText: '',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length != 2) ? 'UF' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('CEP'),
                          TextFormField(
                            controller: _cepController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '00000-000'),
                            validator: (v) =>
                                (v == null || v.trim().length < 8) ? 'CEP inválido' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Ponto de Referência'),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Próximo ao mercado',
                  ),
                ),
              ],
            ),
            _SectionCard(
              number: 3,
              title: 'Quando você precisa?',
              color: const Color(0xFFF59E0B),
              icon: Icons.calendar_month_outlined,
              children: [
                _label('Data Preferida'),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _preferredDate == null
                          ? 'Selecione a data'
                          : _formatDate(_preferredDate!),
                      style: TextStyle(
                        color: _preferredDate == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _label('Período Preferido'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PreferredPeriod.values.map((period) {
                    final selected = _period == period;
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 72) / 2,
                      child: InkWell(
                        onTap: () => setState(() => _period = period),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                period.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? const Color(0xFFB45309)
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                period.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            _SectionCard(
              number: 4,
              title: 'Qual seu orçamento?',
              color: const Color(0xFF22C55E),
              icon: Icons.payments_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Valor Mínimo (R\$)'),
                          TextFormField(
                            controller: _budgetMinController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0,00'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Valor Máximo (R\$)'),
                          TextFormField(
                            controller: _budgetMaxController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0,00'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Aceita negociação de preço?'),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Sim, aceito negociar'),
                  value: true,
                  groupValue: _acceptsNegotiation,
                  onChanged: (v) => setState(() => _acceptsNegotiation = v ?? true),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Não, preço fixo'),
                  value: false,
                  groupValue: _acceptsNegotiation,
                  onChanged: (v) => setState(() => _acceptsNegotiation = v ?? false),
                ),
              ],
            ),
            _SectionCard(
              number: 5,
              title: 'Sobre os materiais',
              color: const Color(0xFF8B5CF6),
              icon: Icons.inventory_2_outlined,
              children: [
                _label('Quem será responsável pelos materiais?'),
                DropdownButtonFormField<String>(
                  value: _materialsResponsible,
                  decoration: const InputDecoration(hintText: 'Selecione uma opção'),
                  items: _materialsOptions
                      .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _materialsResponsible = v),
                  validator: (v) => v == null ? 'Selecione uma opção' : null,
                ),
                const SizedBox(height: 14),
                _label('Detalhes dos Materiais'),
                TextFormField(
                  controller: _materialsDetailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Liste materiais necessários, se houver',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            _SectionCard(
              number: 6,
              title: 'Qual a urgência?',
              color: const Color(0xFFEF4444),
              icon: Icons.priority_high,
              children: [
                _UrgencyTile(
                  selected: _urgency == ServiceUrgency.normal,
                  title: 'Normal (até 7 dias)',
                  subtitle: 'Sem pressa',
                  icon: Icons.schedule,
                  onTap: () => setState(() => _urgency = ServiceUrgency.normal),
                ),
                _UrgencyTile(
                  selected: _urgency == ServiceUrgency.urgent,
                  title: 'Urgente (até 48h)',
                  subtitle: 'Precisa de resolução rápida',
                  icon: Icons.bolt_outlined,
                  onTap: () => setState(() => _urgency = ServiceUrgency.urgent),
                ),
                _UrgencyTile(
                  selected: _urgency == ServiceUrgency.emergency,
                  title: 'Emergência (hoje)',
                  subtitle: 'Atendimento imediato',
                  icon: Icons.warning_amber_rounded,
                  onTap: () => setState(() => _urgency = ServiceUrgency.emergency),
                ),
              ],
            ),
            _SectionCard(
              number: 7,
              title: 'Suas preferências',
              color: const Color(0xFF3B82F6),
              icon: Icons.tune,
              children: [
                _label('Prefere profissional com boas avaliações?'),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Sim, é importante'),
                  value: true,
                  groupValue: _prefersGoodRatings,
                  onChanged: (v) => setState(() => _prefersGoodRatings = v ?? true),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Não importa'),
                  value: false,
                  groupValue: _prefersGoodRatings,
                  onChanged: (v) => setState(() => _prefersGoodRatings = v ?? false),
                ),
                const SizedBox(height: 8),
                _label('Preferência de gênero do profissional?'),
                RadioListTile<GenderPreference>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Sem preferência'),
                  value: GenderPreference.any,
                  groupValue: _genderPreference,
                  onChanged: (v) =>
                      setState(() => _genderPreference = v ?? GenderPreference.any),
                ),
                RadioListTile<GenderPreference>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Masculino'),
                  value: GenderPreference.male,
                  groupValue: _genderPreference,
                  onChanged: (v) =>
                      setState(() => _genderPreference = v ?? GenderPreference.male),
                ),
                RadioListTile<GenderPreference>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Feminino'),
                  value: GenderPreference.female,
                  groupValue: _genderPreference,
                  onChanged: (v) =>
                      setState(() => _genderPreference = v ?? GenderPreference.female),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loading ? null : _submit,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A88E3), Color(0xFF9132CF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9132CF).withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Solicitar Serviço',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 14, color: Color(0xFFEAB308)),
                SizedBox(width: 6),
                Text(
                  'Seus dados estão seguros e protegidos',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final int number;
  final String title;
  final Color color;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.number,
    required this.title,
    required this.color,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.18)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$number. ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _UrgencyTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFEF4444) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFEF4444) : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? const Color(0xFFEF4444) : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
