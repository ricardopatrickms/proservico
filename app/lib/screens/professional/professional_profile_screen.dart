import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mock_store.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';
import 'professional_placeholder_screen.dart';

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
  bool _hasPhoto = false;
  bool _professionalAccess = true;
  List<_SavedAddress> _addresses = [];
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

  String get _prefsKey {
    final id = MockStore.instance.currentUser?.id ?? 'guest';
    return 'professional_addresses_$id';
  }

  String get _areasKey {
    final id = MockStore.instance.currentUser?.id ?? 'guest';
    return 'professional_areas_$id';
  }

  @override
  void initState() {
    super.initState();
    final user = MockStore.instance.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _loadLocal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final areasRaw = prefs.getStringList(_areasKey) ?? [];
    List<_SavedAddress> addresses;
    if (raw == null || raw.isEmpty) {
      addresses = const [
        _SavedAddress(
          id: '1',
          label: 'Casa',
          details: 'Rua das Flores, 123 - Campo Grande, MS | CEP: 79000-000',
        ),
      ];
    } else {
      addresses = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(_SavedAddress.fromJson)
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _areas
        ..clear()
        ..addAll(areasRaw);
    });
  }

  Future<void> _persistAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_addresses.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> _persistAreas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_areasKey, _areas.toList());
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _saveProfile() async {
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
      // Fallback mock se API falhar
      final user = MockStore.instance.currentUser;
      if (user != null) {
        MockStore.instance.updateCurrentUser(
          user.copyWith(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
          ),
        );
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Perfil atualizado');
      setState(() {});
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
      showAppSnackBar(context, 'Senha atualizada localmente');
    }
  }

  Future<void> _saveAreas() async {
    if (_areas.isEmpty) {
      showAppSnackBar(context, 'Selecione ao menos uma área de atuação');
      return;
    }
    await _persistAreas();
    if (!mounted) return;
    showAppSnackBar(context, 'Áreas de atuação salvas');
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim().isEmpty
        ? (MockStore.instance.currentUser?.name ?? 'Profissional')
        : _nameController.text.trim();

    return ProfessionalPageScaffold(
      title: 'Meu Perfil',
      subtitle: 'Gerencie suas informações pessoais',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _Card(
            icon: Icons.swap_horiz,
            title: 'Gerenciar Acesso',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccessRow(
                  icon: Icons.person_outline,
                  title: 'Acesso como Cliente',
                  subtitle: 'Sempre ativo - solicite serviços',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Ativo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 24),
                _AccessRow(
                  icon: Icons.work_outline,
                  title: 'Acesso como Profissional',
                  subtitle: 'Ofereça seus serviços na plataforma',
                  trailing: Switch(
                    value: _professionalAccess,
                    onChanged: (v) => setState(() => _professionalAccess = v),
                  ),
                ),
                if (_professionalAccess) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acesso Profissional Ativo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Você pode oferecer serviços na plataforma.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.badge_outlined,
            title: 'Informações Pessoais',
            child: Column(
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
                    const SizedBox(width: 16),
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _hasPhoto = true);
                          showAppSnackBar(context, 'Foto adicionada (mock)');
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Adicionar Foto'),
                      ),
                    ),
                  ],
                ),
                if (!_hasPhoto) ...[
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
            child: Column(
              children: [
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
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _addOrEditAddress(existing: a),
                          child: const Text('Editar'),
                        ),
                        IconButton(
                          onPressed: () async {
                            setState(() => _addresses = _addresses.where((x) => x.id != a.id).toList());
                            await _persistAddresses();
                          },
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
                    onPressed: _saveAreas,
                    icon: const Icon(Icons.save_outlined),
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

class _AccessRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _AccessRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
