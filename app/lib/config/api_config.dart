import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  /// Prioridade: `--dart-define=API_BASE_URL=...` → `.env` → fallback local.
  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return _normalize(fromDefine);

    final fromEnv = dotenv.maybeGet('API_BASE_URL')?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return _normalize(fromEnv);

    return 'http://127.0.0.1:8000/api';
  }

  /// Base do servidor sem `/api` (para arquivos em `/storage`).
  static String get originUrl {
    return baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  }

  static String resolveStorageUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl
          .replaceFirst('http://localhost:8000', originUrl)
          .replaceFirst('http://127.0.0.1:8000', originUrl);
    }
    final clean = pathOrUrl.replaceFirst(RegExp(r'^/'), '');
    final withStorage =
        clean.startsWith('storage/') ? clean : 'storage/$clean';
    return '$originUrl/$withStorage';
  }

  static String _normalize(String url) {
    return url.replaceAll(RegExp(r'/$'), '');
  }
}
