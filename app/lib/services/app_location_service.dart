import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'cep_service.dart';

class ResolvedAddress {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String cep;

  const ResolvedAddress({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
    required this.cep,
  });
}

class LocationPermissionException implements Exception {
  final String message;
  final bool permanentlyDenied;
  final bool serviceDisabled;

  const LocationPermissionException(
    this.message, {
    this.permanentlyDenied = false,
    this.serviceDisabled = false,
  });

  @override
  String toString() => message;
}

class AppLocationService {
  AppLocationService._();

  static Future<ResolvedAddress> resolveCurrentAddress() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationPermissionException(
        'Ative a localização do aparelho (ou Features → Location no simulador).',
        serviceDisabled: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionException(
        'Permissão de localização negada.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException(
        'Permissão de localização negada. Ative em Ajustes.',
        permanentlyDenied: true,
      );
    }

    final position = await _resolvePosition();
    debugPrint(
      '[Location] GPS ${position.latitude}, ${position.longitude}',
    );

    final fromNative = await _reverseGeocodeNative(
      position.latitude,
      position.longitude,
    );
    if (fromNative != null && _hasUsefulAddress(fromNative)) {
      return fromNative;
    }

    final fromWeb = await _reverseGeocodeNominatim(
      position.latitude,
      position.longitude,
    );
    if (fromWeb != null && _hasUsefulAddress(fromWeb)) {
      return fromWeb;
    }

    // Ainda assim devolve as coordenadas; o usuário completa o endereço.
    return ResolvedAddress(
      latitude: position.latitude,
      longitude: position.longitude,
      address: fromNative?.address ?? fromWeb?.address ?? '',
      city: fromNative?.city ?? fromWeb?.city ?? '',
      state: fromNative?.state ?? fromWeb?.state ?? '',
      cep: fromNative?.cep ?? fromWeb?.cep ?? '',
    );
  }

  static Future<Position> _resolvePosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        // Preferência rápida; se estiver velho demais, busca atual.
        final age = DateTime.now().difference(last.timestamp);
        if (age < const Duration(minutes: 5)) {
          return last;
        }
      }
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationPermissionException(
        'Tempo esgotado ao obter GPS. No simulador: Features → Location → Custom Location.',
      );
    } catch (e) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw LocationPermissionException(
        'Não foi possível obter o GPS. No simulador use Features → Location. ($e)',
      );
    }
  }

  static Future<ResolvedAddress?> _reverseGeocodeNative(
    double latitude,
    double longitude,
  ) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return null;
      return _fromPlacemark(places.first, latitude, longitude);
    } catch (e) {
      debugPrint('[Location] geocoding nativo falhou: $e');
      return null;
    }
  }

  static Future<ResolvedAddress?> _reverseGeocodeNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$latitude&lon=$longitude&addressdetails=1',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'ProServico/1.0 (contato@proservico.app)',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[Location] Nominatim HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      final address = data['address'];
      if (address is! Map) return null;
      final addr = Map<String, dynamic>.from(address);

      final streetName = [
        addr['road'],
        addr['pedestrian'],
        addr['residential'],
      ].whereType<String>().map((e) => e.trim()).firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );
      final houseNumber = addr['house_number']?.toString().trim() ?? '';
      final suburb = [
        addr['suburb'],
        addr['neighbourhood'],
        addr['quarter'],
      ].whereType<String>().map((e) => e.trim()).firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );

      final streetLine = [
        if (streetName.isNotEmpty) streetName,
        if (houseNumber.isNotEmpty) houseNumber,
      ].join(', ');
      final addressLine = [
        if (streetLine.isNotEmpty) streetLine,
        if (suburb.isNotEmpty) suburb,
      ].join(' - ');

      final city = [
        addr['city'],
        addr['town'],
        addr['municipality'],
        addr['village'],
        addr['county'],
      ].whereType<String>().map((e) => e.trim()).firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );

      final state = _toUf(addr['state']?.toString()) ??
          (addr['ISO3166-2-lvl4']?.toString().split('-').last.toUpperCase() ??
              '');

      var cep = _formatCep(addr['postcode']?.toString());
      if (cep.replaceAll(RegExp(r'\D'), '').length == 8) {
        try {
          final viaCep = await CepService.instance.lookup(cep);
          return ResolvedAddress(
            latitude: latitude,
            longitude: longitude,
            address: viaCep.addressLine.isNotEmpty
                ? viaCep.addressLine
                : addressLine,
            city: viaCep.city.isNotEmpty ? viaCep.city : city,
            state: viaCep.state.isNotEmpty ? viaCep.state : state,
            cep: viaCep.cep,
          );
        } catch (_) {}
      }

      return ResolvedAddress(
        latitude: latitude,
        longitude: longitude,
        address: addressLine,
        city: city,
        state: state.length == 2 ? state : (_toUf(state) ?? ''),
        cep: cep,
      );
    } catch (e) {
      debugPrint('[Location] Nominatim falhou: $e');
      return null;
    }
  }

  static ResolvedAddress _fromPlacemark(
    Placemark place,
    double latitude,
    double longitude,
  ) {
    final street = [
      place.thoroughfare,
      place.subThoroughfare,
    ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');

    final address = street.isNotEmpty
        ? street
        : [
            place.street,
            place.name,
          ]
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join(', ');

    final neighborhood = place.subLocality?.trim() ?? '';
    final addressLine = [
      if (address.isNotEmpty) address,
      if (neighborhood.isNotEmpty) neighborhood,
    ].join(' - ');

    final city = (place.subAdministrativeArea?.trim().isNotEmpty == true
            ? place.subAdministrativeArea
            : place.locality)
        ?.trim() ??
        '';

    final state = _toUf(place.administrativeArea) ??
        (place.administrativeArea?.trim().length == 2
            ? place.administrativeArea!.trim().toUpperCase()
            : '');

    return ResolvedAddress(
      latitude: latitude,
      longitude: longitude,
      address: addressLine,
      city: city,
      state: state,
      cep: _formatCep(place.postalCode),
    );
  }

  static bool _hasUsefulAddress(ResolvedAddress value) {
    return value.address.isNotEmpty ||
        value.city.isNotEmpty ||
        value.cep.isNotEmpty;
  }

  static String _formatCep(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return raw?.trim() ?? '';
    return '${digits.substring(0, 5)}-${digits.substring(5)}';
  }

  static String? _toUf(String? administrativeArea) {
    if (administrativeArea == null) return null;
    final value = administrativeArea.trim().toLowerCase();
    if (value.length == 2) return value.toUpperCase();

    const map = {
      'acre': 'AC',
      'alagoas': 'AL',
      'amapá': 'AP',
      'amapa': 'AP',
      'amazonas': 'AM',
      'bahia': 'BA',
      'ceará': 'CE',
      'ceara': 'CE',
      'distrito federal': 'DF',
      'espírito santo': 'ES',
      'espirito santo': 'ES',
      'goiás': 'GO',
      'goias': 'GO',
      'maranhão': 'MA',
      'maranhao': 'MA',
      'mato grosso': 'MT',
      'mato grosso do sul': 'MS',
      'minas gerais': 'MG',
      'pará': 'PA',
      'para': 'PA',
      'paraíba': 'PB',
      'paraiba': 'PB',
      'paraná': 'PR',
      'parana': 'PR',
      'pernambuco': 'PE',
      'piauí': 'PI',
      'piaui': 'PI',
      'rio de janeiro': 'RJ',
      'rio grande do norte': 'RN',
      'rio grande do sul': 'RS',
      'rondônia': 'RO',
      'rondonia': 'RO',
      'roraima': 'RR',
      'santa catarina': 'SC',
      'são paulo': 'SP',
      'sao paulo': 'SP',
      'sergipe': 'SE',
      'tocantins': 'TO',
      'state of são paulo': 'SP',
      'state of sao paulo': 'SP',
      'state of rio de janeiro': 'RJ',
      'state of minas gerais': 'MG',
      'state of paraná': 'PR',
      'state of parana': 'PR',
      'state of rio grande do sul': 'RS',
      'state of santa catarina': 'SC',
      'state of bahia': 'BA',
      'state of pernambuco': 'PE',
      'state of ceará': 'CE',
      'state of ceara': 'CE',
      'federal district': 'DF',
    };

    return map[value];
  }
}
