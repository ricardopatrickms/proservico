import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class CepAddress {
  final String cep;
  final String street;
  final String neighborhood;
  final String city;
  final String state;

  const CepAddress({
    required this.cep,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
  });

  String get addressLine {
    final parts = [
      if (street.trim().isNotEmpty) street.trim(),
      if (neighborhood.trim().isNotEmpty) neighborhood.trim(),
    ];
    return parts.join(', ');
  }
}

/// Consulta de CEP via [ViaCEP](https://viacep.com.br).
class CepService {
  CepService._();
  static final CepService instance = CepService._();

  Future<CepAddress> lookup(String rawCep) async {
    final cep = rawCep.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      throw const ApiException('Informe um CEP válido com 8 dígitos');
    }

    final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Não foi possível consultar o CEP (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const ApiException('Resposta inválida da consulta de CEP');
    }

    final data = Map<String, dynamic>.from(decoded);
    if (data['erro'] == true || data['erro'] == 'true') {
      throw const ApiException('CEP não encontrado');
    }

    final formatted = data['cep']?.toString().trim();
    return CepAddress(
      cep: (formatted != null && formatted.isNotEmpty)
          ? formatted
          : '${cep.substring(0, 5)}-${cep.substring(5)}',
      street: data['logradouro']?.toString().trim() ?? '',
      neighborhood: data['bairro']?.toString().trim() ?? '',
      city: data['localidade']?.toString().trim() ?? '',
      state: data['uf']?.toString().trim().toUpperCase() ?? '',
    );
  }
}
