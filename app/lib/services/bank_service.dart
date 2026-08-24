import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bank.dart';
import 'api_exception.dart';

/// Lista de bancos via [BrasilAPI](https://brasilapi.com.br/docs#tag/BANKS) (gratuita).
class BankService {
  BankService._();
  static final BankService instance = BankService._();

  static const _url = 'https://brasilapi.com.br/api/banks/v1';

  List<Bank>? _cache;

  Future<List<Bank>> list({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    try {
      final response = await http
          .get(Uri.parse(_url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Não foi possível carregar os bancos (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ApiException('Resposta inválida da lista de bancos');
      }

      final banks = decoded
          .whereType<Map>()
          .map((e) => Bank.fromJson(Map<String, dynamic>.from(e)))
          .where((b) => b.code != null && b.fullName.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => (a.code ?? 0).compareTo(b.code ?? 0));

      _cache = banks.isEmpty ? _fallbackBanks : banks;
      return _cache!;
    } on ApiException {
      if (_cache != null) return _cache!;
      _cache = _fallbackBanks;
      return _cache!;
    } catch (_) {
      if (_cache != null) return _cache!;
      _cache = _fallbackBanks;
      return _cache!;
    }
  }

  static const _fallbackBanks = [
    Bank(code: 1, name: 'BCO DO BRASIL S.A.', fullName: 'Banco do Brasil S.A.', ispb: '00000000'),
    Bank(code: 33, name: 'BCO SANTANDER (BRASIL) S.A.', fullName: 'Banco Santander (Brasil) S.A.', ispb: '90400888'),
    Bank(code: 104, name: 'CAIXA ECONOMICA FEDERAL', fullName: 'Caixa Econômica Federal', ispb: '00360305'),
    Bank(code: 237, name: 'BCO BRADESCO S.A.', fullName: 'Banco Bradesco S.A.', ispb: '60746948'),
    Bank(code: 341, name: 'ITAÚ UNIBANCO S.A.', fullName: 'Itaú Unibanco S.A.', ispb: '60701190'),
    Bank(code: 260, name: 'NU PAGAMENTOS S.A.', fullName: 'Nubank', ispb: '18236120'),
    Bank(code: 77, name: 'BANCO INTER', fullName: 'Banco Inter S.A.', ispb: '00416968'),
    Bank(code: 336, name: 'BANCO C6 S.A.', fullName: 'Banco C6 S.A.', ispb: '28326000'),
    Bank(code: 212, name: 'BANCO ORIGINAL', fullName: 'Banco Original S.A.', ispb: '92894922'),
    Bank(code: 290, name: 'PAGSEGURO', fullName: 'PagSeguro Internet S.A.', ispb: '08561701'),
  ];
}
