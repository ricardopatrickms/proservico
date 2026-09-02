class UserAddress {
  final String id;
  final String label;
  final String details;
  final String? address;
  final String? city;
  final String? state;
  final String? cep;
  final String? referencePoint;
  final double? latitude;
  final double? longitude;

  const UserAddress({
    required this.id,
    required this.label,
    required this.details,
    this.address,
    this.city,
    this.state,
    this.cep,
    this.referencePoint,
    this.latitude,
    this.longitude,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'].toString(),
      label: json['label']?.toString() ?? 'Endereço',
      details: json['details']?.toString() ?? '',
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      cep: json['cep']?.toString(),
      referencePoint: json['reference_point']?.toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
    );
  }

  String get displayLine {
    final parts = [
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (cep != null && cep!.trim().isNotEmpty) cep!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' - ');
    return details;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class UserAddressInput {
  final String label;
  final String address;
  final String city;
  final String state;
  final String cep;
  final String? referencePoint;
  final double? latitude;
  final double? longitude;

  const UserAddressInput({
    required this.label,
    required this.address,
    required this.city,
    required this.state,
    required this.cep,
    this.referencePoint,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'city': city,
        'state': state,
        'cep': cep,
        if (referencePoint != null && referencePoint!.trim().isNotEmpty)
          'reference_point': referencePoint!.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}
