import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/helpers.dart';
import 'login_screen.dart';

class ProfessionalRegisterScreen extends StatefulWidget {
  const ProfessionalRegisterScreen({super.key});

  @override
  State<ProfessionalRegisterScreen> createState() => _ProfessionalRegisterScreenState();
}

class _ProfessionalRegisterScreenState extends State<ProfessionalRegisterScreen> {
  static const _steps = [
    'Dados da Conta',
    'Perfil Profissional',
    'Dados Financeiros',
    'Documentos',
  ];

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _loading = false;

  // Step 0 — Conta
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _cpfController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 1 — Perfil
  String? _category;
  final _professionController = TextEditingController();
  String? _experience;
  final _regionController = TextEditingController();

  // Step 2 — Financeiro
  final _bankController = TextEditingController();
  final _agencyController = TextEditingController();
  final _accountController = TextEditingController();
  String? _accountType;
  String? _pixType;
  final _pixKeyController = TextEditingController();

  // Step 3 — Documentos
  _PickedDoc? _idDocument;
  _PickedDoc? _certificate;
  _PickedDoc? _criminalRecord;
  _PickedDoc? _profilePhoto;

  static const _categories = [
    'Elétrica',
    'Hidráulica',
    'Climatização',
    'Pintura',
    'Limpeza',
    'Jardinagem',
    'Marcenaria',
    'Outros',
  ];

  static const _experiences = [
    'Menos de 1 ano',
    '1 a 3 anos',
    '3 a 5 anos',
    '5 a 10 anos',
    'Mais de 10 anos',
  ];

  static const _accountTypes = ['Corrente', 'Poupança'];
  static const _pixTypes = ['CPF', 'CNPJ', 'E-mail', 'Telefone', 'Chave aleatória'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _cpfController.dispose();
    _professionController.dispose();
    _regionController.dispose();
    _bankController.dispose();
    _agencyController.dispose();
    _accountController.dispose();
    _pixKeyController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool _documentsComplete() {
    return _idDocument != null &&
        _certificate != null &&
        _criminalRecord != null &&
        _profilePhoto != null;
  }

  Future<void> _next() async {
    if (!_formKeys[_step].currentState!.validate()) return;
    if (_loading) return;

    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }

    if (!_documentsComplete()) {
      showAppSnackBar(context, 'Envie todos os documentos obrigatórios.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.registerProfessional(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
        cpf: _cpfController.text.trim(),
        category: _category,
        profession: _professionController.text.trim(),
        experience: _experience,
        region: _regionController.text.trim(),
        bank: _bankController.text.trim(),
        agency: _agencyController.text.trim(),
        account: _accountController.text.trim(),
        accountType: _accountType,
        pixType: _pixType,
        pixKey: _pixKeyController.text.trim(),
        idDocumentPath: _idDocument!.path,
        certificatePath: _certificate!.path,
        criminalRecordPath: _criminalRecord!.path,
        profilePhotoPath: _profilePhoto!.path,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Cadastro enviado. Aguarde aprovação do administrador.',
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível concluir o cadastro. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backStep() {
    if (_step == 0) {
      _goHome();
      return;
    }
    setState(() => _step--);
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
                  onTap: () => Navigator.pop(context, _PickSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
                  title: const Text('Galeria'),
                  subtitle: const Text('Selecionar imagem da galeria'),
                  onTap: () => Navigator.pop(context, _PickSource.photo),
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                  title: const Text('Arquivo'),
                  subtitle: const Text('Selecionar PDF ou imagem'),
                  onTap: () => Navigator.pop(context, _PickSource.file),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _assignPicked(String field, _PickedDoc picked) {
    setState(() {
      switch (field) {
        case 'id':
          _idDocument = picked;
        case 'cert':
          _certificate = picked;
        case 'criminal':
          _criminalRecord = picked;
        case 'photo':
          _profilePhoto = picked;
      }
    });
  }

  Future<void> _pickFile(String field) async {
    final source = await _askPickSource();
    if (source == null || !mounted) return;

    // Evita conflito de Activity ao fechar o bottom sheet no Android.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final isProfilePhoto = field == 'photo';
    final maxBytes = isProfilePhoto ? 2 * 1024 * 1024 : 5 * 1024 * 1024;

    try {
      if (source == _PickSource.camera || source == _PickSource.photo) {
        final image = await ImagePicker().pickImage(
          source: source == _PickSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2000,
          requestFullMetadata: false,
        );
        if (image == null) return;

        final size = await File(image.path).length();
        if (size > maxBytes) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            isProfilePhoto
                ? 'A foto deve ter no máximo 2MB.'
                : 'O arquivo deve ter no máximo 5MB.',
          );
          return;
        }

        final name = image.name.isNotEmpty
            ? image.name
            : image.path.split(RegExp(r'[/\\]')).last;
        _assignPicked(field, _PickedDoc(name: name, path: image.path));
        return;
      }

      final result = await FilePicker.pickFiles(
        type: isProfilePhoto ? FileType.image : FileType.custom,
        allowedExtensions: isProfilePhoto ? null : const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final path = file.path;
      if (path == null || path.isEmpty) {
        if (!mounted) return;
        showAppSnackBar(context, 'Não foi possível acessar o arquivo selecionado.');
        return;
      }

      final size = file.size;
      if (size > maxBytes) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          isProfilePhoto
              ? 'A foto deve ter no máximo 2MB.'
              : 'O arquivo deve ter no máximo 5MB.',
        );
        return;
      }

      if (isProfilePhoto) {
        final ext = (file.extension ?? '').toLowerCase();
        if (ext.isNotEmpty && !const ['jpg', 'jpeg', 'png'].contains(ext)) {
          if (!mounted) return;
          showAppSnackBar(context, 'A foto deve ser JPG ou PNG.');
          return;
        }
      }

      _assignPicked(field, _PickedDoc(name: file.name, path: path));
    } on MissingPluginException {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Reinicie o app (pare e rode flutter run) para habilitar a câmera.',
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('camera_access_denied') || msg.contains('CameraAccessDenied')) {
        showAppSnackBar(context, 'Permissão da câmera negada. Ative nas configurações.');
      } else if (msg.contains('channel-error') || msg.contains('MissingPluginException')) {
        showAppSnackBar(
          context,
          'Reinicie o app (pare e rode flutter run) para habilitar a câmera.',
        );
      } else {
        showAppSnackBar(context, 'Não foi possível abrir a câmera. Tente Galeria ou Arquivo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const BrandLogo(fontSize: 20),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _goHome,
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    label: const Text('Voltar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Cadastro de Profissional',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Junte-se à nossa plataforma e expanda seu negócio encontrando novos clientes.',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const _BenefitRow(
                      icon: Icons.verified_outlined,
                      color: AppColors.primary,
                      title: 'Perfil Verificado',
                      description: 'Clientes confiam em profissionais verificados.',
                    ),
                    const SizedBox(height: 8),
                    const _BenefitRow(
                      icon: Icons.build_outlined,
                      color: AppColors.accent,
                      title: 'Destaque suas Habilidades',
                      description: 'Descreva serviços e seja encontrado.',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Criar conta de profissional',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Preencha os dados abaixo para começar a oferecer seus serviços',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _StepTabs(steps: _steps, current: _step),
                          const SizedBox(height: 20),
                          Form(
                            key: _formKeys[_step],
                            child: switch (_step) {
                              0 => _buildAccountStep(),
                              1 => _buildProfileStep(),
                              2 => _buildFinanceStep(),
                              _ => _buildDocumentsStep(),
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (_step > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _backStep,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(color: AppColors.border),
                                      minimumSize: const Size.fromHeight(44),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text('Voltar', maxLines: 1),
                                  ),
                                ),
                              if (_step > 0) const SizedBox(width: 12),
                              Expanded(
                                flex: _step == 0 ? 1 : 1,
                                child: Align(
                                  alignment: _step == 0 ? Alignment.centerRight : Alignment.center,
                                  child: SizedBox(
                                    width: _step == 0 ? 140 : double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _next,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Text(
                                              _step == _steps.length - 1
                                                  ? 'Finalizar cadastro'
                                                  : 'Próximo',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 12),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                const Text(
                                  'Já possui uma conta? ',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Faça login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          label: 'Nome completo *',
          child: TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Digite seu nome completo'),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Obrigatório' : null,
          ),
        ),
        _field(
          label: 'Email *',
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'exemplo@email.com'),
            validator: (v) => (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
          ),
        ),
        _field(
          label: 'Telefone *',
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '(11) 99999-9999'),
            validator: (v) => (v == null || v.trim().length < 8) ? 'Obrigatório' : null,
          ),
        ),
        _field(
          label: 'Senha *',
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Digite sua senha',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
          ),
        ),
        _field(
          label: 'Confirme a senha *',
          child: TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Confirme sua senha',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) => v != _passwordController.text ? 'Senhas não coincidem' : null,
          ),
        ),
        _field(
          label: 'CPF *',
          child: TextFormField(
            controller: _cpfController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '000.000.000-00'),
            validator: (v) => (v == null || v.trim().length < 11) ? 'CPF inválido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          label: 'Categoria de serviço *',
          child: DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(hintText: 'Selecione uma categoria'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Selecione uma categoria' : null,
          ),
        ),
        _field(
          label: 'Profissão *',
          child: TextFormField(
            controller: _professionController,
            decoration: const InputDecoration(hintText: 'Ex: Eletricista, Encanador, etc.'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          ),
        ),
        _field(
          label: 'Tempo de experiência *',
          child: DropdownButtonFormField<String>(
            value: _experience,
            decoration: const InputDecoration(hintText: 'Selecione o tempo de experiência'),
            items: _experiences
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _experience = v),
            validator: (v) => v == null ? 'Selecione o tempo' : null,
          ),
        ),
        _field(
          label: 'Região de atendimento *',
          child: TextFormField(
            controller: _regionController,
            decoration: const InputDecoration(hintText: 'Ex: Zona Sul de São Paulo'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.credit_card_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Dados Financeiros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Preencha seus dados bancários para receber os pagamentos pelos serviços prestados.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _field(
          label: 'Banco *',
          child: TextFormField(
            controller: _bankController,
            decoration: const InputDecoration(hintText: 'Ex: Banco do Brasil, Itaú, etc.'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _field(
                label: 'Agência *',
                child: TextFormField(
                  controller: _agencyController,
                  decoration: const InputDecoration(hintText: '0000'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                label: 'Conta *',
                child: TextFormField(
                  controller: _accountController,
                  decoration: const InputDecoration(hintText: '00000-0'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
              ),
            ),
          ],
        ),
        _field(
          label: 'Tipo de conta *',
          child: DropdownButtonFormField<String>(
            value: _accountType,
            decoration: const InputDecoration(hintText: 'Selecione o tipo de conta'),
            items: _accountTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _accountType = v),
            validator: (v) => v == null ? 'Selecione o tipo' : null,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Chave PIX (opcional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 12),
        _field(
          label: 'Tipo da chave PIX',
          child: DropdownButtonFormField<String>(
            value: _pixType,
            decoration: const InputDecoration(hintText: 'Selecione o tipo da chave PIX'),
            items: _pixTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _pixType = v),
          ),
        ),
        _field(
          label: 'Chave PIX',
          child: TextFormField(
            controller: _pixKeyController,
            decoration: const InputDecoration(hintText: 'Digite sua chave PIX'),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verificação de documentos — Para sua segurança e dos clientes, precisamos verificar seus documentos.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _UploadField(
          title: 'Documento de identidade (RG ou CNH) *',
          hint: 'PDF, JPG ou PNG, máx. 5MB',
          fileName: _idDocument?.name,
          onPick: () => _pickFile('id'),
          onClear: () => setState(() => _idDocument = null),
        ),
        _UploadField(
          title: 'Certificado profissional *',
          hint: 'PDF, JPG ou PNG, máx. 5MB',
          fileName: _certificate?.name,
          onPick: () => _pickFile('cert'),
          onClear: () => setState(() => _certificate = null),
        ),
        _UploadField(
          title: 'Certidão de Antecedentes Criminais *',
          hint: 'PDF, JPG ou PNG, máx. 5MB',
          fileName: _criminalRecord?.name,
          onPick: () => _pickFile('criminal'),
          onClear: () => setState(() => _criminalRecord = null),
        ),
        _UploadField(
          title: 'Foto de perfil *',
          hint: 'JPG ou PNG, máx. 2MB',
          fileName: _profilePhoto?.name,
          onPick: () => _pickFile('photo'),
          onClear: () => setState(() => _profilePhoto = null),
        ),
      ],
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

enum _PickSource { camera, photo, file }

class _PickedDoc {
  final String name;
  final String path;

  const _PickedDoc({required this.name, required this.path});
}

class _StepTabs extends StatefulWidget {
  final List<String> steps;
  final int current;

  const _StepTabs({required this.steps, required this.current});

  @override
  State<_StepTabs> createState() => _StepTabsState();
}

class _StepTabsState extends State<_StepTabs> {
  late final List<GlobalKey> _tabKeys =
      List.generate(widget.steps.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCurrentVisible());
  }

  @override
  void didUpdateWidget(covariant _StepTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCurrentVisible());
    }
  }

  void _ensureCurrentVisible() {
    final ctx = _tabKeys[widget.current].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < widget.steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(
              key: _tabKeys[i],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: i == widget.current
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  bottom: BorderSide(
                    color: i == widget.current ? AppColors.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == widget.current ? AppColors.primary : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: i == widget.current ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.steps[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == widget.current ? FontWeight.w700 : FontWeight.w500,
                      color: i == widget.current ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadField extends StatelessWidget {
  final String title;
  final String hint;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _UploadField({
    required this.title,
    required this.hint,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: fileName == null ? AppColors.border : AppColors.primary.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onPick,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Escolher arquivo'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fileName ?? 'Nenhum arquivo escolhido',
                        style: TextStyle(
                          fontSize: 12,
                          color: fileName == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (fileName != null)
                      IconButton(
                        onPressed: onClear,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
