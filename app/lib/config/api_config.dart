import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? '';
    if (kIsWeb || raw.isEmpty) return raw;
    if (!Platform.isAndroid) return raw;

    // No emulador Android, 127.0.0.1 é o próprio emulador — o PC é 10.0.2.2.
    return raw
        .replaceFirst('://127.0.0.1', '://10.0.2.2')
        .replaceFirst('://localhost', '://10.0.2.2');
  }

  /// Monta a URL pública do arquivo a partir do host em `API_BASE_URL`.
  static String resolveStorageUrl(String pathOrUrl) {
    var path = pathOrUrl.contains('://')
        ? Uri.parse(pathOrUrl).path
        : pathOrUrl;
    path = path.replaceFirst(RegExp(r'^/'), '');
    if (!path.startsWith('storage/')) path = 'storage/$path';
    return '${baseUrl.replaceAll('/api', '')}/$path';
  }
}
