import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL']!;

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
