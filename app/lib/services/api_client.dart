import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'session_expiry.dart';
import 'session_store.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tag = 'ApiClient';

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[$_tag] $message');
    developer.log(message, name: _tag);
  }

  Uri _uri(String path) {
    final base = ApiConfig.baseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = SessionStore.instance.accessToken;
    if (auth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool auth = false,
  }) async {
    final uri = _uri(path);
    _log('GET $uri');
    final response = await _send(
      () => http.get(uri, headers: _headers(auth: auth)),
      method: 'GET',
      uri: uri,
    );
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<List<dynamic>> getList(
    String path, {
    bool auth = false,
  }) async {
    final uri = _uri(path);
    _log('GET $uri');
    final response = await _send(
      () => http.get(uri, headers: _headers(auth: auth)),
      method: 'GET',
      uri: uri,
    );
    return _decodeList(response, auth: auth, path: path);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = _uri(path);
    _log('POST $uri');
    if (body != null) {
      _log('body keys: ${body.keys.join(', ')}');
    }
    final response = await _send(
      () => http.post(
        uri,
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
      method: 'POST',
      uri: uri,
    );
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final response = await _send(
      () => http.patch(
        _uri(path),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = false,
  }) async {
    final response = await _send(
      () => http.delete(_uri(path), headers: _headers(auth: auth)),
    );
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, String> files = const {},
    Map<String, List<String>> fileLists = const {},
    bool auth = false,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers['Accept'] = 'application/json';
    final token = SessionStore.instance.accessToken;
    if (auth && token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }
    for (final entry in fileLists.entries) {
      for (final filePath in entry.value) {
        request.files.add(
          await http.MultipartFile.fromPath('${entry.key}[]', filePath),
        );
      }
    }

    final response = await _send(() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }, timeout: const Duration(seconds: 60));
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<Map<String, dynamic>> putMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, String> files = const {},
    bool auth = false,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers['Accept'] = 'application/json';
    final token = SessionStore.instance.accessToken;
    if (auth && token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll({...fields, '_method': 'PUT'});
    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }

    final response = await _send(() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }, timeout: const Duration(seconds: 60));
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final response = await _send(
      () => http.put(
        _uri(path),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeMap(response, auth: auth, path: path);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 20),
    String method = 'REQUEST',
    Uri? uri,
  }) async {
    final started = DateTime.now();
    try {
      final response = await request().timeout(timeout);
      final ms = DateTime.now().difference(started).inMilliseconds;
      _log(
        '$method ${uri ?? ''} → ${response.statusCode} (${ms}ms) '
        'body=${_preview(response.body)}',
      );
      return response;
    } on ApiException {
      rethrow;
    } catch (e, st) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      _log(
        'FALHA $method ${uri ?? ''} após ${ms}ms: '
        '${e.runtimeType}: $e',
      );
      _log('stack: $st');
      throw ApiException(
        'Não foi possível conectar à API. Verifique se o servidor está rodando. ($e)',
      );
    }
  }

  String _preview(String body, {int max = 400}) {
    if (body.isEmpty) return '(vazio)';
    final compact = body.replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= max) return compact;
    return '${compact.substring(0, max)}…';
  }

  Map<String, dynamic> _decodeMap(
    http.Response response, {
    required bool auth,
    required String path,
  }) {
    final decoded = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    _handleUnauthorizedIfNeeded(response, auth: auth, path: path, decoded: decoded);
    final error = _error(response, decoded);
    _log('erro HTTP ${response.statusCode} em $path: ${error.displayMessage}');
    throw error;
  }

  List<dynamic> _decodeList(
    http.Response response, {
    required bool auth,
    required String path,
  }) {
    final decoded = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) {
        return decoded['data'] as List;
      }
      return const [];
    }
    _handleUnauthorizedIfNeeded(response, auth: auth, path: path, decoded: decoded);
    throw _error(response, decoded);
  }

  void _handleUnauthorizedIfNeeded(
    http.Response response, {
    required bool auth,
    required String path,
    dynamic decoded,
  }) {
    if (response.statusCode != 401 || !auth) return;

    final normalized = path.toLowerCase();
    if (normalized.contains('/auth/login') ||
        normalized.contains('/auth/register') ||
        normalized.contains('/auth/forgot-password') ||
        normalized.contains('/auth/reset-password')) {
      return;
    }

    Map<String, dynamic> data = {};
    if (decoded is Map<String, dynamic>) data = decoded;
    final exception = ApiException(
      data['message']?.toString() ?? 'Unauthenticated.',
      statusCode: 401,
    );
    if (!exception.isSessionExpired) return;

    SessionExpiry.handleUnauthorized();
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  ApiException _error(http.Response response, dynamic decoded) {
    Map<String, dynamic> data = {};
    if (decoded is Map<String, dynamic>) data = decoded;
    final rawMessage = data['message']?.toString().trim();
    return ApiException(
      (rawMessage != null && rawMessage.isNotEmpty)
          ? rawMessage
          : 'Erro na requisição (${response.statusCode})',
      statusCode: response.statusCode,
      errors: data['errors'] is Map<String, dynamic>
          ? data['errors'] as Map<String, dynamic>
          : null,
    );
  }
}
