import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../data/client_requests_store.dart';
import '../../models/service_request.dart';
import '../../services/app_image_picker.dart';
import '../../services/app_location_service.dart';
import '../../services/api_exception.dart';
import '../../services/cep_service.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cep_input_formatter.dart';
import '../../widgets/currency_input_formatter.dart';
import '../../widgets/helpers.dart';
import '../../widgets/service_category_picker.dart';

/// Formulário completo de edição — mesmos campos de Solicitar Serviço.
class EditServiceSheet extends StatefulWidget {
  final ServiceRequest request;

  const EditServiceSheet({super.key, required this.request});

  @override
  State<EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<EditServiceSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _numberController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _cepController;
  late final TextEditingController _referenceController;
  late final TextEditingController _budgetMinController;
  late final TextEditingController _budgetMaxController;
  late final TextEditingController _materialsDetailsController;

  String? _category;
  DateTime? _preferredDate;
  PreferredPeriod? _period;
  bool _acceptsNegotiation = true;
  String? _materialsResponsible;
  ServiceUrgency _urgency = ServiceUrgency.normal;
  bool _prefersGoodRatings = true;
  GenderPreference _genderPreference = GenderPreference.any;
  final List<XFile> _newPhotos = [];
  late List<String> _keptPaths;
  bool _saving = false;
  bool _locating = false;
  bool _lookingUpCep = false;
  double? _latitude;
  double? _longitude;
  String? _lastLookedUpCep;

  static const _materialsOptions = <(String, String)>[
    ('client', 'Cliente fornece os materiais'),
    ('professional', 'Profissional fornece os materiais'),
    ('shared', 'A combinar / compartilhar'),
  ];

  static const _maxPhotoBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    final hasStructured = r.address?.trim().isNotEmpty == true ||
        r.city?.trim().isNotEmpty == true;

    _titleController = TextEditingController(text: r.title);
    _descriptionController = TextEditingController(text: r.description);
    _addressController = TextEditingController(
      text: r.address?.trim().isNotEmpty == true
          ? r.address!.trim()
          : (hasStructured ? '' : r.location),
    );
    _numberController = TextEditingController(text: r.number?.trim() ?? '');
    _cityController = TextEditingController(text: r.city?.trim() ?? '');
    _stateController = TextEditingController(text: r.state?.trim() ?? '');
    _cepController = TextEditingController(text: r.cep?.trim() ?? '');
    _referenceController =
        TextEditingController(text: r.referencePoint?.trim() ?? '');
    _budgetMinController =
        TextEditingController(text: _budgetText(r.budgetMin));
    _budgetMaxController =
        TextEditingController(text: _budgetText(r.budgetMax ?? r.budget));
    _materialsDetailsController =
        TextEditingController(text: r.materialsDetails?.trim() ?? '');

    final rawCategory = (r.category ?? '').trim();
    _category = rawCategory.isNotEmpty ? rawCategory : null;
    _preferredDate = DateTime(
      r.scheduledAt.year,
      r.scheduledAt.month,
      r.scheduledAt.day,
    );
    _period = r.preferredPeriod ?? PreferredPeriod.business;
    _acceptsNegotiation = r.acceptsNegotiation;
    _materialsResponsible = r.materialsResponsible;
    _urgency = r.urgency;
    _prefersGoodRatings = r.prefersGoodRatings ?? true;
    _genderPreference = r.genderPreference ?? GenderPreference.any;
    _latitude = r.latitude;
    _longitude = r.longitude;
    _keptPaths = List<String>.from(
      r.photoPaths.where((p) => p.trim().isNotEmpty && !p.startsWith('http')),
    );
    // Fallback: se a API só mandou URLs em photos, tenta extrair path relativo.
    if (_keptPaths.isEmpty) {
      for (final url in r.photoUrls) {
        final path = _storagePathFromUrl(url);
        if (path != null) _keptPaths.add(path);
      }
    }
  }

  String? _storagePathFromUrl(String urlOrPath) {
    final raw = urlOrPath.trim();
    if (raw.isEmpty) return null;
    if (!raw.contains('://')) {
      return raw.replaceFirst(RegExp(r'^/'), '').replaceFirst('storage/', '');
    }
    final path = Uri.tryParse(raw)?.path ?? '';
    final marker = '/storage/';
    final idx = path.indexOf(marker);
    if (idx >= 0) return path.substring(idx + marker.length);
    return path.replaceFirst(RegExp(r'^/'), '').replaceFirst('storage/', '');
  }

  String _urlForKeptPath(String path) {
    final index = widget.request.photoPaths.indexOf(path);
    if (index >= 0 && index < widget.request.photoUrls.length) {
      return ApiConfig.resolveStorageUrl(widget.request.photoUrls[index]);
    }
    return ApiConfig.resolveStorageUrl(path);
  }

  String _budgetText(double? value) {
    if (value == null) return '';
    final cents = (value * 100).round().toString();
    return CurrencyInputFormatter.formatFromDigits(cents);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _numberController.dispose();
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
    final now = DateTime.now();
    final initial = _preferredDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _preferredDate = picked);
    }
  }

  Future<void> _onCepChanged(String value) async {
    final digits = CepInputFormatter.digitsOnly(value);
    if (digits.length != 8) {
      setState(() {});
      return;
    }
    if (_lookingUpCep || digits == _lastLookedUpCep) {
      setState(() {});
      return;
    }
    await _lookupCep(digits);
  }

  Future<void> _lookupCep([String? raw]) async {
    final digits = CepInputFormatter.digitsOnly(raw ?? _cepController.text);
    if (digits.length != 8 || _lookingUpCep) return;

    setState(() => _lookingUpCep = true);
    try {
      final address = await CepService.instance.lookup(digits);
      if (!mounted) return;
      setState(() {
        _lastLookedUpCep = digits;
        _cepController.value = TextEditingValue(
          text: address.cep,
          selection: TextSelection.collapsed(offset: address.cep.length),
        );
        if (address.addressLine.isNotEmpty) {
          _addressController.text = address.addressLine;
        }
        if (address.city.isNotEmpty) _cityController.text = address.city;
        if (address.state.isNotEmpty) _stateController.text = address.state;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível consultar o CEP.');
    } finally {
      if (mounted) setState(() => _lookingUpCep = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final resolved = await AppLocationService.resolveCurrentAddress();
      if (!mounted) return;
      setState(() {
        _latitude = resolved.latitude;
        _longitude = resolved.longitude;
        if (resolved.address.isNotEmpty) {
          _addressController.text = resolved.address;
        }
        if (resolved.number.isNotEmpty) {
          _numberController.text = resolved.number;
        }
        if (resolved.city.isNotEmpty) _cityController.text = resolved.city;
        if (resolved.state.isNotEmpty) _stateController.text = resolved.state;
        if (resolved.cep.isNotEmpty) {
          _cepController.text = resolved.cep;
          _lastLookedUpCep = CepInputFormatter.digitsOnly(resolved.cep);
        }
      });
      showAppSnackBar(context, 'Localização preenchida. Confira os dados.');
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível obter a localização.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    try {
      final image = await AppImagePicker.pickImage(
        source: source,
        maxWidth: 1920,
      );
      if (image == null || !mounted) return;
      final bytes = await image.length();
      if (!mounted) return;
      if (bytes > _maxPhotoBytes) {
        showAppSnackBar(context, 'Cada foto deve ter no máximo 5 MB');
        return;
      }
      setState(() => _newPhotos.add(image));
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível adicionar a foto.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _category!.isEmpty) {
      showAppSnackBar(context, 'Selecione o tipo de serviço');
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
    if (_materialsResponsible == null) {
      showAppSnackBar(context, 'Selecione a responsabilidade dos materiais');
      return;
    }

    final budgetMin = CurrencyInputFormatter.parse(_budgetMinController.text);
    final budgetMax = CurrencyInputFormatter.parse(_budgetMaxController.text);
    if (budgetMin != null && budgetMax != null && budgetMin > budgetMax) {
      showAppSnackBar(context, 'O valor mínimo não pode ser maior que o máximo');
      return;
    }

    final existingCount = _keptPaths.length + _newPhotos.length;
    if (existingCount < 2) {
      showAppSnackBar(
        context,
        'Mantenha no mínimo 2 fotos do problema',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ClientRequestsStore.instance.update(
        widget.request.id,
        CreateServiceRequestInput(
          title: _titleController.text.trim(),
          category: _category!,
          description: _descriptionController.text.trim(),
          address: _addressController.text.trim(),
          number: _numberController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim().toUpperCase(),
          cep: _cepController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
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
          photoPaths: _newPhotos.map((p) => p.path).toList(),
          keepPhotoPaths: List<String>.from(_keptPaths),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível salvar as alterações.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final photoCount = _keptPaths.length + _newPhotos.length;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Editar Serviço',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed:
                                  _saving ? null : () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTitle('1. Sobre o serviço'),
                            _label('Categoria do serviço'),
                            ServiceCategoryPicker(
                              value: _category,
                              onChanged: (v) => setState(() => _category = v),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Selecione a categoria'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _label('Título do Serviço'),
                            TextFormField(
                              controller: _titleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Ex: Troca de chuveiro',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe o título'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _label('Descrição Detalhada'),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Descreva o problema',
                                alignLabelWithHint: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe a descrição'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _label('Fotos do Problema'),
                            if (photoCount > 0) ...[
                              SizedBox(
                                height: 88,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: photoCount,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final isKept = i < _keptPaths.length;
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: isKept
                                              ? Image.network(
                                                  _urlForKeptPath(
                                                    _keptPaths[i],
                                                  ),
                                                  width: 88,
                                                  height: 88,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                    width: 88,
                                                    height: 88,
                                                    color: AppColors.border,
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                                )
                                              : Image.file(
                                                  File(
                                                    _newPhotos[i -
                                                            _keptPaths.length]
                                                        .path,
                                                  ),
                                                  width: 88,
                                                  height: 88,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: _saving
                                                ? null
                                                : () => setState(() {
                                                      if (isKept) {
                                                        _keptPaths
                                                            .removeAt(i);
                                                      } else {
                                                        _newPhotos.removeAt(
                                                          i -
                                                              _keptPaths
                                                                  .length,
                                                        );
                                                      }
                                                    }),
                                            child: const CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.black54,
                                              child: Icon(
                                                Icons.close,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              photoCount < 2
                                  ? 'Mínimo de 2 fotos. Adicione ou remova conforme precisar.'
                                  : 'Toque no X para remover. Você pode adicionar mais fotos.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _addPhoto,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Adicionar fotos'),
                            ),

                            _sectionTitle('2. Onde será o serviço?'),
                            OutlinedButton.icon(
                              onPressed: _locating || _saving
                                  ? null
                                  : _useCurrentLocation,
                              icon: _locating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                              label: Text(
                                _locating
                                    ? 'Obtendo GPS...'
                                    : 'Usar localização atual',
                              ),
                            ),
                            const SizedBox(height: 14),
                            _label('CEP'),
                            TextFormField(
                              controller: _cepController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CepInputFormatter()],
                              decoration: InputDecoration(
                                hintText: '00000-000',
                                suffixIcon: _lookingUpCep
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: _lookingUpCep
                                            ? null
                                            : () => _lookupCep(),
                                        icon: const Icon(Icons.search),
                                      ),
                              ),
                              onChanged: _onCepChanged,
                              validator: (v) {
                                if (v == null ||
                                    CepInputFormatter.digitsOnly(v).length !=
                                        8) {
                                  return 'Informe um CEP válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _label('Endereço'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _addressController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      hintText: 'Rua e bairro',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Informe o endereço'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _numberController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'Nº',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Informe o nº'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _label('Cidade'),
                            TextFormField(
                              controller: _cityController,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(hintText: 'Cidade'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Informe a cidade'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            _label('Estado'),
                            TextFormField(
                              controller: _stateController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 2,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z]'),
                                ),
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'UF',
                                counterText: '',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length != 2)
                                      ? 'Informe a UF'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            _label('Ponto de Referência'),
                            TextFormField(
                              controller: _referenceController,
                              decoration: const InputDecoration(
                                hintText: 'Ex: Próximo ao mercado',
                              ),
                            ),

                            _sectionTitle('3. Quando você precisa?'),
                            _label('Data Preferida'),
                            InkWell(
                              onTap: _saving ? null : _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon:
                                      Icon(Icons.calendar_today_outlined),
                                ),
                                child: Text(
                                  _preferredDate == null
                                      ? 'Selecione a data'
                                      : '${_preferredDate!.day.toString().padLeft(2, '0')}/${_preferredDate!.month.toString().padLeft(2, '0')}/${_preferredDate!.year}',
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: PreferredPeriod.values.map((period) {
                                final selected = _period == period;
                                return SizedBox(
                                  width:
                                      (MediaQuery.of(context).size.width - 72) /
                                          2,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _period = period),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.12)
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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

                            _sectionTitle('4. Qual seu orçamento?'),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Valor Mínimo (R\$)'),
                                      TextFormField(
                                        controller: _budgetMinController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: const [
                                          CurrencyInputFormatter(),
                                        ],
                                        decoration: const InputDecoration(
                                          hintText: '0,00',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Valor Máximo (R\$)'),
                                      TextFormField(
                                        controller: _budgetMaxController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: const [
                                          CurrencyInputFormatter(),
                                        ],
                                        decoration: const InputDecoration(
                                          hintText: '0,00',
                                        ),
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
                              onChanged: (v) => setState(
                                () => _acceptsNegotiation = v ?? true,
                              ),
                            ),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Não, preço fixo'),
                              value: false,
                              groupValue: _acceptsNegotiation,
                              onChanged: (v) => setState(
                                () => _acceptsNegotiation = v ?? false,
                              ),
                            ),

                            _sectionTitle('5. Sobre os materiais'),
                            _label('Quem será responsável pelos materiais?'),
                            DropdownButtonFormField<String>(
                              value: _materialsResponsible,
                              decoration: const InputDecoration(
                                hintText: 'Selecione uma opção',
                              ),
                              items: _materialsOptions
                                  .map(
                                    (o) => DropdownMenuItem(
                                      value: o.$1,
                                      child: Text(o.$2),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _materialsResponsible = v),
                              validator: (v) =>
                                  v == null ? 'Selecione uma opção' : null,
                            ),
                            const SizedBox(height: 14),
                            _label('Detalhes dos Materiais'),
                            TextFormField(
                              controller: _materialsDetailsController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText:
                                    'Liste materiais necessários, se houver',
                                alignLabelWithHint: true,
                              ),
                            ),

                            _sectionTitle('6. Qual a urgência?'),
                            ...ServiceUrgency.values.map((u) {
                              final selected = _urgency == u;
                              final (title, subtitle, icon) = switch (u) {
                                ServiceUrgency.normal => (
                                    'Normal (até 7 dias)',
                                    'Sem pressa',
                                    Icons.schedule,
                                  ),
                                ServiceUrgency.urgent => (
                                    'Urgente (até 48h)',
                                    'Precisa de resolução rápida',
                                    Icons.bolt_outlined,
                                  ),
                                ServiceUrgency.emergency => (
                                    'Emergência (hoje)',
                                    'Atendimento imediato',
                                    Icons.warning_amber_rounded,
                                  ),
                              };
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () => setState(() => _urgency = u),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: selected ? 1.5 : 1,
                                      ),
                                      color: selected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.08)
                                          : AppColors.surface,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(icon, color: AppColors.primary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                subtitle,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            _sectionTitle('7. Suas preferências'),
                            _label(
                              'Prefere profissional com boas avaliações?',
                            ),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Sim, é importante'),
                              value: true,
                              groupValue: _prefersGoodRatings,
                              onChanged: (v) => setState(
                                () => _prefersGoodRatings = v ?? true,
                              ),
                            ),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Não importa'),
                              value: false,
                              groupValue: _prefersGoodRatings,
                              onChanged: (v) => setState(
                                () => _prefersGoodRatings = v ?? false,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _label('Preferência de gênero do profissional?'),
                            RadioListTile<GenderPreference>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Sem preferência'),
                              value: GenderPreference.any,
                              groupValue: _genderPreference,
                              onChanged: (v) => setState(
                                () => _genderPreference =
                                    v ?? GenderPreference.any,
                              ),
                            ),
                            RadioListTile<GenderPreference>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Masculino'),
                              value: GenderPreference.male,
                              groupValue: _genderPreference,
                              onChanged: (v) => setState(
                                () => _genderPreference =
                                    v ?? GenderPreference.male,
                              ),
                            ),
                            RadioListTile<GenderPreference>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Feminino'),
                              value: GenderPreference.female,
                              groupValue: _genderPreference,
                              onChanged: (v) => setState(
                                () => _genderPreference =
                                    v ?? GenderPreference.female,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: AppColors.primary,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Salvar Alterações'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed:
                                  _saving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
