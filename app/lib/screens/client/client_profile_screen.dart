import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mock_store.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';

class _SavedAddress {
  final String id;
  final String label;
  final String details;

  const _SavedAddress({
    required this.id,
    required this.label,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'details': details,
      };

  factory _SavedAddress.fromJson(Map<String, dynamic> json) {
    return _SavedAddress(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Endereço',
      details: json['details']?.toString() ?? '',
    );
  }
}

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
  bool _hasPhoto = false;
  List<_SavedAddress> _addresses = [];

  String get _prefsKey {
    final id = MockStore.instance.currentUser?.id ?? 'guest';
    return 'client_addresses_$id';
  }

  @override
  void initState() {
    super.initState();
    final user = MockStore.instance.currentUser!;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
    _loadAddresses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      setState(() {
        _addresses = const [
          _SavedAddress(
            id: '1',
            label: 'Casa',
            details: 'Rua das Flores, 123 - Campo Grande, MS | CEP: 79000-000',
          ),
        ];
      });
      return;
    }
    final list = (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(_SavedAddress.fromJson)
        .toList();
    if (mounted) setState(() => _addresses = list);
  }

  Future<void> _persistAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_addresses.map((a) => a.toJson()).toList()),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) return list.first[0].toUpperCase();
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }

  Future<void> _save() async {
    if (_loading) return;
    if (!_hasPhoto) {
      showAppSnackBar(context, 'Foto de perfil é obrigatória');
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: MockStore.instance.currentUser?.city,
      );
      if (!mounted) return;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      showAppSnackBar(context, 'Perfil atualizado');
      setState(() {});
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

  Future<void> _addOrEditAddress({_SavedAddress? existing}) async {
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

    setState(() {
      if (existing == null) {
        _addresses = [
          ..._addresses,
          _SavedAddress(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            details: details,
          ),
        ];
      } else {
        _addresses = _addresses
            .map(
              (a) => a.id == existing.id
                  ? _SavedAddress(id: a.id, label: label, details: details)
                  : a,
            )
            .toList();
      }
    });
    await _persistAddresses();
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

            // Informações Pessoais
            _ProfileCard(
              icon: Icons.person_outline,
              title: 'Informações Pessoais',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
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
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _hasPhoto = true);
                                showAppSnackBar(context, 'Foto adicionada (simulado)');
                              },
                              icon: const Icon(Icons.photo_camera_outlined, size: 18),
                              label: Text(_hasPhoto ? 'Trocar Foto' : 'Adicionar Foto'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '* Foto de perfil é obrigatória',
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasPhoto ? AppColors.textSecondary : AppColors.danger,
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
                    readOnly: true,
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

            // Endereços
            _ProfileCard(
              icon: Icons.list_alt_outlined,
              title: 'Endereços Salvos',
              child: Column(
                children: [
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
                            onPressed: () async {
                              setState(() {
                                _addresses =
                                    _addresses.where((a) => a.id != address.id).toList();
                              });
                              await _persistAddresses();
                            },
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

            // Segurança
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
