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

enum _PickSource { camera, gallery }

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _loading = false;
  bool _loadingAddresses = true;
  String? _pickedPhotoPath;
  String? _existingPhotoUrl;
  List<UserAddress> _addresses = [];

  @override
  void initState() {
    super.initState();
    final user = MockStore.instance.currentUser!;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
    _existingPhotoUrl = user.profilePhotoUrl;
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
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) return list.first[0].toUpperCase();
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
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

  Future<void> _save() async {
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
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

  @override
  Widget build(BuildContext context) {
    final user = MockStore.instance.currentUser;
    final name = _nameController.text.trim().isEmpty
        ? (user?.name ?? 'Cliente')
        : _nameController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const Text(
              'Meu Perfil',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gerencie suas informações pessoais',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            _ProfileCard(
              icon: Icons.person_outline,
              title: 'Informações Pessoais',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildAvatar(name),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.photo_camera_outlined, size: 18),
                              label: Text(_hasProfilePhoto ? 'Trocar Foto' : 'Adicionar Foto'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '* Foto de perfil é obrigatória',
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasProfilePhoto
                                    ? AppColors.textSecondary
                                    : AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel('Nome Completo'),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Seu nome'),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('E-mail'),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'seu@email.com'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ao alterar o email, você receberá um link de confirmação',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Telefone'),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: '(00) 00000-0000'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            _ProfileCard(
              icon: Icons.list_alt_outlined,
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
                        for (final address in _addresses) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_outlined, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.label,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address.details,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _addOrEditAddress(existing: address),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: () => _deleteAddress(address),
                                  tooltip: 'Excluir',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _addOrEditAddress(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('+ Adicionar Novo Endereço'),
                          ),
                        ),
                      ],
                    ),
            ),
            _ProfileCard(
              icon: Icons.shield_outlined,
              title: 'Segurança',
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Alterar Senha'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      alignment: Alignment.centerLeft,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      showConfirmDialog(
                        context: context,
                        title: 'Excluir Conta',
                        message:
                            'Esta ação não está disponível no Módulo 1. Em breve você poderá excluir sua conta.',
                        onConfirm: () {},
                      );
                    },
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    label: const Text(
                      'Excluir Conta',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      alignment: Alignment.centerLeft,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
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

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
