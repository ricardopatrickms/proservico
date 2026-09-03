import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_address.dart';
import '../services/api_exception.dart';
import '../services/app_location_service.dart';
import '../services/cep_service.dart';
import '../theme/app_theme.dart';
import 'cep_input_formatter.dart';
import 'helpers.dart';

Future<UserAddressInput?> showAddressFormDialog({
  required BuildContext context,
  UserAddress? existing,
}) {
  return Navigator.of(context).push<UserAddressInput>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _AddressFormDialog(existing: existing),
    ),
  );
}

class _AddressFormDialog extends StatefulWidget {
  final UserAddress? existing;

  const _AddressFormDialog({this.existing});

  @override
  State<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<_AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _cepController;
  late final TextEditingController _addressController;
  late final TextEditingController _numberController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _referenceController;

  bool _lookingUpCep = false;
  bool _locating = false;
  String? _lastLookedUpCep;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _cepController = TextEditingController(text: existing?.cep ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _numberController = TextEditingController(text: existing?.number ?? '');
    _cityController = TextEditingController(text: existing?.city ?? '');
    _stateController = TextEditingController(text: existing?.state ?? '');
    _referenceController =
        TextEditingController(text: existing?.referencePoint ?? '');
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    final digits = CepInputFormatter.digitsOnly(_cepController.text);
    if (digits.length == 8) _lastLookedUpCep = digits;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _cepController.dispose();
    _addressController.dispose();
    _numberController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _onCepChanged(String value) async {
    final digits = CepInputFormatter.digitsOnly(value);
    if (digits.length != 8 || _lookingUpCep || digits == _lastLookedUpCep) {
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
    } on LocationPermissionException catch (e) {
      if (!mounted) return;
      if (e.permanentlyDenied) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'Ajustes', onPressed: openAppSettings),
          ),
        );
      } else {
        showAppSnackBar(context, e.message);
      }
    } on MissingPluginException {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Reinicie o app (pare e rode flutter run) para habilitar a localização.',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível obter a localização.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      UserAddressInput(
        label: _labelController.text.trim(),
        address: _addressController.text.trim(),
        number: _numberController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim().toUpperCase(),
        cep: _cepController.text.trim(),
        referencePoint: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Novo endereço' : 'Editar endereço'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    TextFormField(
                      controller: _labelController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Apelido',
                        hintText: 'Ex: Casa, Trabalho',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o apelido'
                          : null,
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cepController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CepInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'CEP',
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
                                onPressed:
                                    _lookingUpCep ? null : () => _lookupCep(),
                                icon: const Icon(Icons.search),
                              ),
                      ),
                      onChanged: _onCepChanged,
                      validator: (v) {
                        if (v == null ||
                            CepInputFormatter.digitsOnly(v).length != 8) {
                          return 'Informe um CEP válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _addressController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Endereço',
                              hintText: 'Rua e bairro',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe o endereço'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _numberController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Número',
                              hintText: 'Nº',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe o número'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        hintText: 'Cidade',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a cidade'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stateController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        hintText: 'UF',
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().length != 2)
                          ? 'Informe a UF'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Ponto de referência',
                        hintText: 'Ex: Próximo ao mercado',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
