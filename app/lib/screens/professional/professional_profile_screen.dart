import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../data/mock_store.dart';
import '../../models/user_address.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import 'professional_placeholder_screen.dart';

enum _PickSource { camera, gallery }

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({super.key});

  @override
  State<ProfessionalProfileScreen> createState() => _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _loading = false;
  bool _loadingProfile = true;
  bool _loadingAddresses = true;
  bool _savingAreas = false;
  String? _pickedPhotoPath;
  String? _existingPhotoUrl;
  List<UserAddress> _addresses = [];
  final Set<String> _areas = {};

  static const _availableAreas = [
    'Serviços Domésticos',
    'Transporte',
    'Saúde e Bem-estar',
    'Eventos e Festas',
    'Serviços Criativos',
    'Construção e Reforma',
    'Tecnologia',
    'Educacionais',
    'Administrativos',
  ];

  @override
  void initState() {
    super.initState();
    final user = MockStore.instance.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _existingPhotoUrl = user?.profilePhotoUrl;
    _areas.addAll(user?.serviceAreas ?? const []);
    _loadProfile();
    _loadAddresses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _hasProfilePhoto =>
      _pickedPhotoPath != null ||
      (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final user = await AuthService.instance.fetchMe();
      if (!mounted) return;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      setState(() {
        _existingPhotoUrl = user.profilePhotoUrl;
        _areas
          ..clear()
          ..addAll(user.serviceAreas);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível carregar o perfil.');
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final addresses = await AddressService.instance.list();
      if (!mounted) return;
      setState(() => _addresses = addresses);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível carregar os endereços.');
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<_PickSource?> _askPickSource() {
    return showModalBottomSheet<_PickSource>(
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
                      'Como deseja enviar?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                  title: const Text('Câmera'),
                  subtitle: const Text('Tirar uma foto agora'),
                  onTap: () => Navigator.pop(context, _PickSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
                  title: const Text('Galeria'),
                  subtitle: const Text('Selecionar imagem da galeria'),
                  onTap: () => Navigator.pop(context, _PickSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    final source = await _askPickSource();
    if (source == null || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source == _PickSource.camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
        requestFullMetadata: false,
      );
      if (image == null) return;

      final size = await File(image.path).length();
      if (size > 2 * 1024 * 1024) {
        if (!mounted) return;
        showAppSnackBar(context, 'A foto deve ter no máximo 2MB.');
        return;
      }

      setState(() => _pickedPhotoPath = image.path);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível selecionar a foto.');
    }
  }

  Widget _buildAvatar(String name) {
    if (_pickedPhotoPath != null) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: FileImage(File(_pickedPhotoPath!)),
      );
    }

    if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(
          ApiConfig.resolveStorageUrl(_existingPhotoUrl!),
        ),
      );
    }

    return CircleAvatar(
      radius: 36,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        _initials(name),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_loading) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      showAppSnackBar(context, 'Informe o nome completo');
      return;
    }
    if (!email.contains('@')) {
      showAppSnackBar(context, 'Informe um e-mail válido');
      return;
    }
    if (!_hasProfilePhoto) {
      showAppSnackBar(context, 'Foto de perfil é obrigatória');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.updateProfile(
        name: name,
        email: email,
        phone: phone,
        city: MockStore.instance.currentUser?.city,
        profilePhotoPath: _pickedPhotoPath,
      );
      if (!mounted) return;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      setState(() {
        _existingPhotoUrl = user.profilePhotoUrl;
        _pickedPhotoPath = null;
      });
      showAppSnackBar(context, 'Perfil atualizado');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível atualizar o perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEditAddress({UserAddress? existing}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Novo endereço' : 'Editar endereço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Apelido (ex: Casa)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Endereço completo',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (saved != true) return;
    final label = labelCtrl.text.trim();
    final details = detailsCtrl.text.trim();
    if (!mounted) return;
    if (label.isEmpty || details.isEmpty) {
      showAppSnackBar(context, 'Preencha apelido e endereço');
      return;
    }

    try {
      if (existing == null) {
        final created = await AddressService.instance.create(
          label: label,
          details: details,
        );
        if (!mounted) return;
        setState(() => _addresses = [..._addresses, created]);
      } else {
        final updated = await AddressService.instance.update(
          id: existing.id,
          label: label,
          details: details,
        );
        if (!mounted) return;
        setState(() {
          _addresses = _addresses
              .map((a) => a.id == existing.id ? updated : a)
              .toList();
        });
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Endereço salvo');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível salvar o endereço.');
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    try {
      await AddressService.instance.delete(address.id);
      if (!mounted) return;
      setState(() {
        _addresses = _addresses.where((a) => a.id != address.id).toList();
      });
      showAppSnackBar(context, 'Endereço removido');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível remover o endereço.');
    }
  }

  Future<void> _changePassword() async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;
    if (passCtrl.text.length < 8) {
      showAppSnackBar(context, 'A senha deve ter no mínimo 8 caracteres');
      return;
    }
    if (passCtrl.text != confirmCtrl.text) {
      showAppSnackBar(context, 'As senhas não coincidem');
      return;
    }

    try {
      await AuthService.instance.updatePassword(
        password: passCtrl.text,
        passwordConfirmation: confirmCtrl.text,
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Senha atualizada');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível alterar a senha');
    }
  }

  Future<void> _saveAreas() async {
    if (_savingAreas) return;
    if (_areas.isEmpty) {
      showAppSnackBar(context, 'Selecione ao menos uma área de atuação');
      return;
    }

    setState(() => _savingAreas = true);
    try {
      final user = await AuthService.instance.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        city: MockStore.instance.currentUser?.city,
        serviceAreas: _areas.toList(),
      );
      if (!mounted) return;
      setState(() => _areas..clear()..addAll(user.serviceAreas));
      showAppSnackBar(context, 'Áreas de atuação salvas');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível salvar as áreas.');
    } finally {
      if (mounted) setState(() => _savingAreas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim().isEmpty
        ? (MockStore.instance.currentUser?.name ?? 'Profissional')
        : _nameController.text.trim();

    if (_loadingProfile) {
      return const ProfessionalPageScaffold(
        title: 'Meu Perfil',
        subtitle: 'Gerencie suas informações pessoais',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ProfessionalPageScaffold(
      title: 'Meu Perfil',
      subtitle: 'Gerencie suas informações pessoais',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _Card(
            icon: Icons.badge_outlined,
            title: 'Informações Pessoais',
            child: Column(
              children: [
                Row(
                  children: [
                    _buildAvatar(name),
                    const SizedBox(width: 16),
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(_hasProfilePhoto ? 'Trocar Foto' : 'Adicionar Foto'),
                      ),
                    ),
                  ],
                ),
                if (!_hasProfilePhoto) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '* Foto de perfil é obrigatória',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    hintText: 'Seu nome completo',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    helperText: 'Ao alterar o email, você receberá um link de confirmação',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Salvar Alterações'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.location_on_outlined,
            title: 'Endereços Salvos',
            child: _loadingAddresses
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      if (_addresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Nenhum endereço salvo ainda.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ..._addresses.map(
                        (a) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      a.details,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _addOrEditAddress(existing: a),
                                child: const Text('Editar'),
                              ),
                              IconButton(
                                onPressed: () => _deleteAddress(a),
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _addOrEditAddress(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size(double.infinity, 46),
                        ),
                        child: const Text('+ Adicionar Novo Endereço'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.lock_outline,
            title: 'Segurança',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Alterar Senha'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                  title: const Text('Excluir Conta', style: TextStyle(color: AppColors.danger)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.danger),
                  onTap: () => showAppSnackBar(context, 'Disponível em breve'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.category_outlined,
            title: 'Áreas de Atuação',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _areas.isEmpty
                      ? 'Nenhuma área selecionada ainda.'
                      : '${_areas.length} área(s) selecionada(s)',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecione ao menos uma área disponível:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 560 ? 2 : 1;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableAreas.map((area) {
                        final selected = _areas.contains(area);
                        return SizedBox(
                          width: cols == 2 ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth,
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selected,
                            title: Text(area, style: const TextStyle(fontSize: 13.5)),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _areas.add(area);
                                } else {
                                  _areas.remove(area);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _savingAreas ? null : _saveAreas,
                    icon: _savingAreas
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salvar Alterações'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                    ),
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

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
