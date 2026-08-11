import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Override: `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000/api`
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // Emulador Android acessa o host via 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  /// Base do servidor sem `/api` (para arquivos em `/storage`).
  static String get originUrl {
    return baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  }

  static String resolveStorageUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl.replaceFirst('http://localhost:8000', originUrl)
          .replaceFirst('http://127.0.0.1:8000', originUrl);
    }
    final clean = pathOrUrl.replaceFirst(RegExp(r'^/'), '');
    final withStorage = clean.startsWith('storage/') ? clean : 'storage/$clean';
    return '$originUrl/$withStorage';
  }
}
