import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'session_store.dart';

class AuthResult {
  final String accessToken;
  final AppUser user;
  final String? message;

  const AuthResult({
    required this.accessToken,
    required this.user,
    this.message,
  });
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;

  Future<AuthResult> registerClient({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) {
    return _register({
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'type': 'client',
    });
  }

  Future<AuthResult> registerProfessional({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String cpf,
    String? category,
    String? profession,
    String? experience,
    String? region,
    String? bank,
    String? agency,
    String? account,
    String? accountType,
    String? pixType,
    String? pixKey,
    required String idDocumentPath,
    required String certificatePath,
    required String criminalRecordPath,
    required String profilePhotoPath,
  }) async {
    final data = await _api.postMultipart(
      '/auth/register',
      fields: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'type': 'professional',
        'cpf': cpf,
        if (category != null) 'category': category,
        if (profession != null) 'profession': profession,
        if (experience != null) 'experience': experience,
        if (region != null) 'region': region,
        if (bank != null) 'bank': bank,
        if (agency != null) 'agency': agency,
        if (account != null) 'account': account,
        if (accountType != null) 'account_type': accountType,
        if (pixType != null) 'pix_type': pixType,
        if (pixKey != null && pixKey.isNotEmpty) 'pix_key': pixKey,
      },
      files: {
        'id_document': idDocumentPath,
        'certificate': certificatePath,
        'criminal_record': criminalRecordPath,
        'profile_photo': profilePhotoPath,
      },
    );
    return _persist(data);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    return _persist(data);
  }

  Future<AppUser> updateProfile({
    required String name,
    required String phone,
    String? city,
  }) async {
    final data = await _api.put(
      '/auth/profile',
      auth: true,
      body: {
        'name': name,
        'phone': phone,
        'city': city,
      },
    );
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const ApiException('Resposta inválida da API');
    }
    final user = AppUser.fromJson(userJson);
    final token = SessionStore.instance.accessToken ?? '';
    await SessionStore.instance.saveSession(token: token, user: user);
    return user;
  }

  Future<AppUser> updatePassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _api.put(
      '/auth/profile',
      auth: true,
      body: {
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const ApiException('Resposta inválida da API');
    }
    return AppUser.fromJson(userJson);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', auth: true);
    } catch (_) {
      // Limpa sessão local mesmo se a API falhar.
    }
    await SessionStore.instance.clear();
  }

  Future<AuthResult> _register(Map<String, dynamic> body) async {
    final data = await _api.post('/auth/register', body: body);
    return _persist(data);
  }

  Future<AuthResult> _persist(Map<String, dynamic> data) async {
    final token = data['access_token']?.toString();
    final userJson = data['user'];
    if (token == null || userJson is! Map<String, dynamic>) {
      throw const ApiException('Resposta inválida da API');
    }

    final user = AppUser.fromJson(userJson);
    await SessionStore.instance.saveSession(token: token, user: user);

    return AuthResult(
      accessToken: token,
      user: user,
      message: data['message']?.toString(),
    );
  }
}
