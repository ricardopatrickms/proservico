import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
import '../professional/professional_request_detail_sheet.dart';

class RequestServiceScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;

  const RequestServiceScreen({super.key, this.onSubmitted});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _categoryKey = GlobalKey();
  final _titleKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _photosKey = GlobalKey();
  final _addressKey = GlobalKey();
  final _cityKey = GlobalKey();
  final _stateKey = GlobalKey();
  final _cepKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _periodKey = GlobalKey();
  final _budgetKey = GlobalKey();
  final _materialsKey = GlobalKey();

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
  bool _locating = false;
  bool _lookingUpCep = false;
  bool _attempted = false;
  Map<String, String> _apiFieldErrors = {};
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
    _scrollController.dispose();
    super.dispose();
  }

  void _clearApi(String field) {
    if (!_apiFieldErrors.containsKey(field)) return;
    setState(() => _apiFieldErrors.remove(field));
  }

  AutovalidateMode get _fieldValidateMode =>
      _attempted ? AutovalidateMode.always : AutovalidateMode.disabled;

  String? _apiError(String field) => _apiFieldErrors[field];

  void _notifyMissingFields(String message) {
    final bottom = MediaQuery.paddingOf(context).bottom + 88;
    showAppSnackBar(context, message, bottomMargin: bottom);
  }

  String? get _photosError {
    if (_attempted && _photos.length < 2) {
      return 'Envie no mínimo 2 fotos para continuar';
    }
    return _apiError('photos');
  }

  String? get _dateError {
    if (_attempted && _preferredDate == null) {
      return 'Selecione a data preferida';
    }
    return _apiError('scheduled_at');
  }

  String? get _periodError {
    if (_attempted && _period == null) {
      return 'Selecione o período preferido';
    }
    return _apiError('preferred_period');
  }

  String? get _budgetRangeError {
    final min = _parseBudget(_budgetMinController.text);
    final max = _parseBudget(_budgetMaxController.text);
    if (min != null && max != null && min > max) {
      return 'O valor mínimo não pode ser maior que o máximo';
    }
    return _apiError('budget') ?? _apiError('budget_min') ?? _apiError('budget_max');
  }

  double? _parseBudget(String raw) => CurrencyInputFormatter.parse(raw);

  Map<String, String> _mapApiErrors(ApiException e) {
    final errors = e.errors;
    if (errors == null || errors.isEmpty) return {};
    final out = <String, String>{};
    for (final entry in errors.entries) {
      final key = entry.key.split('.').first;
      if (out.containsKey(key)) continue;
      final raw = entry.value is List && (entry.value as List).isNotEmpty
          ? (entry.value as List).first.toString()
          : entry.value.toString();
      out[key] = _friendlyFieldError(key, raw);
    }
    return out;
  }

  String _friendlyFieldError(String field, String raw) {
    const byField = {
      'title': 'Informe o título',
      'category': 'Selecione a categoria',
      'description': 'Informe a descrição',
      'location': 'Informe o endereço completo',
      'address': 'Informe o endereço',
      'city': 'Informe a cidade',
      'state': 'Informe a UF (2 letras)',
      'cep': 'Informe um CEP válido',
      'scheduled_at': 'Selecione a data preferida',
      'preferred_period': 'Selecione o período preferido',
      'materials_responsible': 'Selecione quem será responsável pelos materiais',
      'photos': 'Envie no mínimo 2 fotos (JPG, PNG ou WEBP, máx. 5 MB)',
      'budget': 'Informe um orçamento válido',
      'budget_min': 'Informe um valor mínimo válido',
      'budget_max': 'Informe um valor máximo válido',
    };
    final lower = raw.toLowerCase();
    if (field == 'photos') {
      if (lower.contains('mimes') || lower.contains('image')) {
        return 'Use fotos em JPG, PNG ou WEBP';
      }
      if (lower.contains('max.file') || lower.contains('max')) {
        return 'Cada foto deve ter no máximo 5 MB';
      }
      if (lower.contains('min')) {
        return 'Envie no mínimo 2 fotos para continuar';
      }
    }
    if (raw.startsWith('validation.required') || raw == 'validation.required') {
      return byField[field] ?? 'Este campo é obrigatório';
    }
    if (raw.startsWith('validation.')) {
      return byField[field] ?? 'Verifique este campo';
    }
    return raw.trim().isEmpty ? (byField[field] ?? 'Verifique este campo') : raw;
  }

  List<String> _missingFieldLabels({
    required bool photosOk,
    required bool dateOk,
    required bool periodOk,
    required bool budgetOk,
    required bool formOk,
  }) {
    final missing = <String>[];
    if (_category == null || _category!.trim().isEmpty) {
      missing.add('Categoria');
    }
    if (_titleController.text.trim().isEmpty) missing.add('Título');
    if (_descriptionController.text.trim().isEmpty) missing.add('Descrição');
    if (!photosOk) missing.add('Fotos (mínimo 2)');
    if (_addressController.text.trim().isEmpty) missing.add('Endereço');
    if (_cityController.text.trim().isEmpty) missing.add('Cidade');
    if (_stateController.text.trim().length != 2) missing.add('Estado (UF)');
    if (CepInputFormatter.digitsOnly(_cepController.text).length != 8) {
      missing.add('CEP');
    }
    if (!dateOk) missing.add('Data preferida');
    if (!periodOk) missing.add('Período preferido');
    if (!budgetOk) missing.add('Orçamento');
    if (_materialsResponsible == null) missing.add('Materiais');
    if (missing.isEmpty && !formOk) missing.add('Categoria');
    return missing;
  }

  String _missingFieldsMessage(List<String> labels) {
    if (labels.isEmpty) {
      return 'Preencha os campos destacados em vermelho.';
    }
    if (labels.length == 1) return 'Preencha: ${labels.first}.';
    final shown = labels.take(3).join(', ');
    final extra = labels.length > 3 ? '…' : '';
    return 'Preencha os campos destacados: $shown$extra.';
  }

  Future<bool> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
    return true;
  }

  void _scheduleScrollToFirstError({
    required bool photosOk,
    required bool dateOk,
    required bool periodOk,
    required bool budgetOk,
    bool formOk = true,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToFirstError(
          photosOk: photosOk,
          dateOk: dateOk,
          periodOk: periodOk,
          budgetOk: budgetOk,
          formOk: formOk,
        );
      });
    });
  }

  Future<void> _scrollToFirstError({
    required bool photosOk,
    required bool dateOk,
    required bool periodOk,
    required bool budgetOk,
    bool formOk = true,
  }) async {
    final targets = <GlobalKey>[
      if (_category == null ||
          _category!.trim().isEmpty ||
          _apiError('category') != null)
        _categoryKey,
      if (_titleController.text.trim().isEmpty || _apiError('title') != null)
        _titleKey,
      if (_descriptionController.text.trim().isEmpty ||
          _apiError('description') != null)
        _descriptionKey,
      if (!photosOk || _apiError('photos') != null) _photosKey,
      if (_addressController.text.trim().isEmpty ||
          _apiError('address') != null ||
          _apiError('location') != null)
        _addressKey,
      if (_cityController.text.trim().isEmpty || _apiError('city') != null)
        _cityKey,
      if (_stateController.text.trim().length != 2 || _apiError('state') != null)
        _stateKey,
      if (CepInputFormatter.digitsOnly(_cepController.text).length != 8 ||
          _apiError('cep') != null)
        _cepKey,
      if (!dateOk || _apiError('scheduled_at') != null) _dateKey,
      if (!periodOk || _apiError('preferred_period') != null) _periodKey,
      if (!budgetOk ||
          _apiError('budget') != null ||
          _apiError('budget_min') != null ||
          _apiError('budget_max') != null)
        _budgetKey,
      if (_materialsResponsible == null ||
          _apiError('materials_responsible') != null)
        _materialsKey,
    ];

    if (!formOk && targets.isEmpty) {
      targets.add(_categoryKey);
    }

    for (final key in targets) {
      if (await _scrollToKey(key)) return;
    }

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
    setState(() {
      _preferredDate = date;
      _apiFieldErrors.remove('scheduled_at');
    });
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
                if (AppImagePicker.isCameraAvailable)
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

      setState(() {
        _photos.add(image);
        _apiFieldErrors.remove('photos');
      });
    } on CameraUnavailableException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } on MediaPermissionDeniedException catch (e) {
      if (!mounted) return;
      showMediaPermissionSnackBar(context, e);
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
    if (_loading) return;

    setState(() {
      _attempted = true;
      _apiFieldErrors = {};
    });

    bool formOk = false;
    try {
      formOk = _formKey.currentState?.validate() ?? false;
    } catch (_) {
      formOk = false;
    }
    final photosOk = _photos.length >= 2;
    final dateOk = _preferredDate != null;
    final periodOk = _period != null;
    final budgetMin = _parseBudget(_budgetMinController.text);
    final budgetMax = _parseBudget(_budgetMaxController.text);
    final budgetOk = budgetMin == null || budgetMax == null || budgetMin <= budgetMax;

    if (!formOk || !photosOk || !dateOk || !periodOk || !budgetOk) {
      final labels = _missingFieldLabels(
        photosOk: photosOk,
        dateOk: dateOk,
        periodOk: periodOk,
        budgetOk: budgetOk,
        formOk: formOk,
      );
      _notifyMissingFields(_missingFieldsMessage(labels));
      _scheduleScrollToFirstError(
        photosOk: photosOk,
        dateOk: dateOk,
        periodOk: periodOk,
        budgetOk: budgetOk,
        formOk: formOk,
      );
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
      await showProfessionalRequestDetail(context, created);
    } on ApiException catch (e) {
      if (!mounted) return;
      final mapped = _mapApiErrors(e);
      if (mapped.isNotEmpty) {
        setState(() => _apiFieldErrors = mapped);
        _formKey.currentState?.validate();
        _notifyMissingFields(
          'Não foi possível enviar. Verifique os campos destacados.',
        );
        _scheduleScrollToFirstError(
          photosOk: _photos.length >= 2 && mapped['photos'] == null,
          dateOk: _preferredDate != null && mapped['scheduled_at'] == null,
          periodOk: _period != null && mapped['preferred_period'] == null,
          budgetOk: mapped['budget'] == null &&
              mapped['budget_min'] == null &&
              mapped['budget_max'] == null,
          formOk: false,
        );
        return;
      }
      showAppSnackBar(context, e.displayMessage, bottomMargin: MediaQuery.paddingOf(context).bottom + 88);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível enviar a solicitação.', bottomMargin: MediaQuery.paddingOf(context).bottom + 88);
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
      _attempted = false;
      _apiFieldErrors = {};
      _latitude = null;
      _longitude = null;
      _locating = false;
      _lookingUpCep = false;
      _lastLookedUpCep = null;
    });
  }

  Future<void> _onCepChanged(String value) async {
    _clearApi('cep');
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
          _clearApi('address');
          _clearApi('location');
        }
        if (address.city.isNotEmpty) {
          _cityController.text = address.city;
          _clearApi('city');
        }
        if (address.state.isNotEmpty) {
          _stateController.text = address.state;
          _clearApi('state');
        }
        _clearApi('cep');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _lastLookedUpCep = digits;
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

      final filledSomething = resolved.address.isNotEmpty ||
          resolved.city.isNotEmpty ||
          resolved.cep.isNotEmpty;

      setState(() {
        _latitude = resolved.latitude;
        _longitude = resolved.longitude;
        if (resolved.address.isNotEmpty) {
          _addressController.text = resolved.address;
          _clearApi('address');
          _clearApi('location');
        }
        if (resolved.city.isNotEmpty) {
          _cityController.text = resolved.city;
          _clearApi('city');
        }
        if (resolved.state.isNotEmpty) {
          _stateController.text = resolved.state;
          _clearApi('state');
        }
        if (resolved.cep.isNotEmpty) {
          _cepController.text = resolved.cep;
          _lastLookedUpCep = CepInputFormatter.digitsOnly(resolved.cep);
          _clearApi('cep');
        }
      });

      showAppSnackBar(
        context,
        filledSomething
            ? 'Localização preenchida. Confira os dados.'
            : 'GPS obtido. Complete o endereço ou busque pelo CEP.',
      );
    } on LocationPermissionException catch (e) {
      if (!mounted) return;
      if (e.permanentlyDenied) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: openAppSettings,
            ),
          ),
        );
      } else if (e.serviceDisabled) {
        showAppSnackBar(context, e.message);
      } else {
        showAppSnackBar(context, e.message);
      }
    } on MissingPluginException {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Reinicie o app (pare e rode flutter run) para habilitar a localização.',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Não foi possível obter a localização. Tente novamente.',
      );
      debugPrint('[Location] erro: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
        autovalidateMode: _fieldValidateMode,
        child: ListView(
          controller: _scrollController,
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
            if (_attempted) _missingFieldsBanner(),
            if (_attempted) const SizedBox(height: 16),
            _SectionCard(
              number: 1,
              title: 'Qual serviço você precisa?',
              color: AppColors.primary,
              icon: Icons.handyman_outlined,
              children: [
                KeyedSubtree(
                  key: _categoryKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Categoria do serviço'),
                      ServiceCategoryPicker(
                        value: _category,
                        prefixIcon: const Icon(Icons.lightbulb_outline),
                        autovalidateMode: _fieldValidateMode,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Selecione a categoria';
                          }
                          return _apiError('category');
                        },
                        onChanged: (v) => setState(() {
                          _category = v;
                          _apiFieldErrors.remove('category');
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _titleKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Título do Serviço'),
                      TextFormField(
                        autovalidateMode: _fieldValidateMode,
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Troca de tomada na sala',
                        ),
                        onChanged: (_) => _clearApi('title'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe o título';
                          }
                          return _apiError('title');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _descriptionKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Descrição Detalhada'),
                      TextFormField(
                        autovalidateMode: _fieldValidateMode,
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Descreva o problema ou o serviço desejado',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => _clearApi('description'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe a descrição';
                          }
                          return _apiError('description');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _photosKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Fotos do Problema'),
                      InkWell(
                        onTap: _loading ? null : _addPhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _photosError != null
                                ? AppColors.danger.withValues(alpha: 0.04)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _photosError != null
                                  ? AppColors.danger
                                  : AppColors.border,
                              style: BorderStyle.solid,
                              width: _photosError != null ? 1.6 : 1.4,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Toque para adicionar fotos',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'JPG, PNG ou WEBP (máx. 5 MB)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
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
                                        onTap: () => setState(() {
                                          _photos.removeAt(index);
                                          if (_photos.length >= 2) {
                                            _apiFieldErrors.remove('photos');
                                          }
                                        }),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
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
                        _photosError ??
                            'Você precisa enviar no mínimo 2 fotos para continuar',
                        style: TextStyle(
                          color: _photosError != null
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _locating
                        ? 'Obtendo localização...'
                        : 'Usar minha localização',
                  ),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _cepKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('CEP'),
                      TextFormField(
                        autovalidateMode: _fieldValidateMode,
                        controller: _cepController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          CepInputFormatter(),
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '00000-000',
                          suffixIcon: _lookingUpCep
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Buscar CEP',
                                  onPressed: _lookingUpCep ? null : () => _lookupCep(),
                                  icon: const Icon(Icons.search),
                                ),
                        ),
                        onChanged: _onCepChanged,
                        validator: (v) {
                          if (v == null ||
                              CepInputFormatter.digitsOnly(v).length != 8) {
                            return 'Informe um CEP válido';
                          }
                          return _apiError('cep');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _addressKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Endereço Completo'),
                      TextFormField(
                        autovalidateMode: _fieldValidateMode,
                        controller: _addressController,
                        decoration: const InputDecoration(
                          hintText: 'Rua, número e bairro',
                        ),
                        onChanged: (_) {
                          _clearApi('address');
                          _clearApi('location');
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe o endereço';
                          }
                          return _apiError('address') ?? _apiError('location');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _cityKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Cidade'),
                      TextFormField(
                        autovalidateMode: _fieldValidateMode,
                        controller: _cityController,
                        decoration: const InputDecoration(hintText: 'Cidade'),
                        onChanged: (_) => _clearApi('city'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe a cidade';
                          }
                          return _apiError('city');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _stateKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Estado'),
                      TextFormField(
                        autovalidateMode: _fieldValidateMode,
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
                        onChanged: (_) => _clearApi('state'),
                        validator: (v) {
                          if (v == null || v.trim().length != 2) {
                            return 'Informe a UF';
                          }
                          return _apiError('state');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _label('Ponto de Referência'),
                TextFormField(
                  controller: _referenceController,
                  autovalidateMode: _fieldValidateMode,
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
                KeyedSubtree(
                  key: _dateKey,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        errorText: _dateError,
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
                ),
                const SizedBox(height: 14),
                _label('Período Preferido'),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: _periodKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PreferredPeriod.values.map((period) {
                          final selected = _period == period;
                          final hasError = _periodError != null && !selected;
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 72) / 2,
                            child: InkWell(
                              onTap: () => setState(() {
                                _period = period;
                                _apiFieldErrors.remove('preferred_period');
                              }),
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
                                        : hasError
                                            ? AppColors.danger
                                            : AppColors.border,
                                    width: selected || hasError ? 1.5 : 1,
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
                      if (_periodError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 12),
                          child: Text(
                            _periodError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            _SectionCard(
              number: 4,
              title: 'Qual seu orçamento?',
              color: const Color(0xFF22C55E),
              icon: Icons.payments_outlined,
              children: [
                Column(
                  key: _budgetKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                autovalidateMode: _fieldValidateMode,
                                keyboardType: TextInputType.number,
                                inputFormatters: const [
                                  CurrencyInputFormatter(),
                                ],
                                decoration: const InputDecoration(hintText: '0,00'),
                                onChanged: (_) {
                                  _clearApi('budget_min');
                                  _clearApi('budget_max');
                                  _clearApi('budget');
                                  setState(() {});
                                },
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
                                autovalidateMode: _fieldValidateMode,
                                keyboardType: TextInputType.number,
                                inputFormatters: const [
                                  CurrencyInputFormatter(),
                                ],
                                decoration: const InputDecoration(hintText: '0,00'),
                                onChanged: (_) {
                                  _clearApi('budget_min');
                                  _clearApi('budget_max');
                                  _clearApi('budget');
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_budgetRangeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Text(
                          _budgetRangeError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
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
                KeyedSubtree(
                  key: _materialsKey,
                  child: DropdownButtonFormField<String>(
                    value: _materialsResponsible,
                    autovalidateMode: _fieldValidateMode,
                    decoration: const InputDecoration(
                      hintText: 'Selecione uma opção',
                    ),
                    items: _materialsOptions
                        .map(
                          (o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _materialsResponsible = v;
                      _apiFieldErrors.remove('materials_responsible');
                    }),
                    validator: (v) {
                      if (v == null) return 'Selecione uma opção';
                      return _apiError('materials_responsible');
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _label('Detalhes dos Materiais'),
                TextFormField(
                  controller: _materialsDetailsController,
                  autovalidateMode: _fieldValidateMode,
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

  Widget _missingFieldsBanner() {
    final min = _parseBudget(_budgetMinController.text);
    final max = _parseBudget(_budgetMaxController.text);
    final labels = _missingFieldLabels(
      photosOk: _photos.length >= 2,
      dateOk: _preferredDate != null,
      periodOk: _period != null,
      budgetOk: min == null || max == null || min <= max,
      formOk: _category != null && _category!.trim().isNotEmpty,
    );
    if (labels.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _missingFieldsMessage(labels),
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
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
      clipBehavior: Clip.none,
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
