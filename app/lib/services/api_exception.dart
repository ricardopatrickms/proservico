class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? errors;

  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.errors,
  });

  @override
  String toString() => message;

  /// 401 de token inválido/expirado (não confundir com login com senha errada).
  bool get isSessionExpired {
    if (statusCode != 401) return false;
    final lower = message.toLowerCase();
    return lower.contains('unauthenticated') ||
        lower.contains('token') ||
        lower.contains('jwt') ||
        lower.contains('blacklisted') ||
        lower.contains('authorization');
  }

  /// Conta inativada/excluída/rejeitada enquanto a sessão ainda existia.
  bool get isAccountInactive {
    if (code == 'account_inactive') return true;
    if (statusCode != 403) return false;
    final lower = message.toLowerCase();
    return lower.contains('conta inativa') ||
        lower.contains('cadastro excluído') ||
        lower.contains('cadastro profissional rejeitado');
  }

  /// Primeira mensagem de validação do Laravel, se houver.
  String get displayMessage {
    if (isAccountInactive) {
      return message.trim().isNotEmpty ? message : 'Conta inativa';
    }
    if (isSessionExpired) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (errors != null && errors!.isNotEmpty) {
      final entry = errors!.entries.first;
      final first = entry.value;
      final raw = first is List && first.isNotEmpty
          ? first.first.toString()
          : first.toString();
      final friendly = _friendly(raw, entry.key).trim();
      if (friendly.isNotEmpty) return friendly;
    }
    final friendly = _friendly(message, null).trim();
    if (friendly.isNotEmpty) return friendly;
    return 'Não foi possível concluir. Tente novamente.';
  }

  static String _friendly(String raw, String? field) {
    const byKey = {
      'validation.unique': 'Este valor já está cadastrado.',
      'validation.max.string': 'Algum campo ultrapassou o tamanho máximo.',
      'validation.required': 'Preencha todos os campos obrigatórios.',
      'validation.email': 'Informe um e-mail válido.',
      'validation.exists': 'Informe um e-mail válido.',
      'validation.confirmed': 'A confirmação da senha não confere.',
      'validation.size.string': 'Valor em formato inválido.',
      'validation.min.string': 'Valor muito curto.',
    };

    final byField = {
      'email': {
        'validation.unique': 'Este e-mail já está cadastrado.',
        'validation.email': 'Informe um e-mail válido.',
        'validation.exists': 'Informe um e-mail válido.',
      },
      'cpf': {
        'validation.unique': 'Este CPF já está cadastrado.',
        'validation.size.string': 'Informe um CPF válido com 11 dígitos.',
        'validation.max.string': 'Informe um CPF válido.',
      },
      'phone': {
        'validation.max.string': 'Informe um telefone válido.',
        'validation.min.string': 'Informe um telefone válido.',
      },
      'id_document': {
        'validation.required': 'O documento de identidade é obrigatório.',
        'validation.mimes': 'Documento inválido. Use PDF, JPG ou PNG.',
        'validation.max.file': 'O documento deve ter no máximo 5MB.',
      },
      'certificate': {
        'validation.required': 'O certificado profissional é obrigatório.',
        'validation.mimes': 'Certificado inválido. Use PDF, JPG ou PNG.',
        'validation.max.file': 'O certificado deve ter no máximo 5MB.',
      },
      'criminal_record': {
        'validation.required': 'A certidão de antecedentes é obrigatória.',
        'validation.mimes': 'Arquivo inválido. Use PDF, JPG ou PNG.',
        'validation.max.file': 'O arquivo deve ter no máximo 5MB.',
      },
      'profile_photo': {
        'validation.required': 'A foto de perfil é obrigatória.',
        'validation.mimes': 'Foto inválida. Use JPG ou PNG.',
        'validation.max.file': 'A foto deve ter no máximo 2MB.',
      },
    };

    if (field != null && byField[field]?[raw] != null) {
      return byField[field]![raw]!;
    }
    if (byKey[raw] != null) return byKey[raw]!;
    if (raw.startsWith('validation.')) {
      return 'Não foi possível concluir. Verifique os dados e tente novamente.';
    }
    return raw;
  }
}
