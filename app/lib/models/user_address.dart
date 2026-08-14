class UserAddress {
  final String id;
  final String label;
  final String details;

  const UserAddress({
    required this.id,
    required this.label,
    required this.details,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'].toString(),
      label: json['label']?.toString() ?? 'Endereço',
      details: json['details']?.toString() ?? '',
    );
  }
}
