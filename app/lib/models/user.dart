enum AccountType { client, professional, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final AccountType type;
  final String? city;
  final String? bio;
  final bool approved;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    this.city,
    this.bio,
    this.approved = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      type: accountTypeFromApi(json['type']?.toString()),
      city: json['city']?.toString(),
      bio: json['bio']?.toString(),
      approved: json['approved'] == true || json['approved'] == 1,
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? bio,
    bool? approved,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      approved: approved ?? this.approved,
    );
  }
}

AccountType accountTypeFromApi(String? value) {
  switch (value) {
    case 'professional':
      return AccountType.professional;
    case 'admin':
      return AccountType.admin;
    default:
      return AccountType.client;
  }
}

extension AccountTypeApi on AccountType {
  String get apiValue => switch (this) {
        AccountType.client => 'client',
        AccountType.professional => 'professional',
        AccountType.admin => 'admin',
      };
}
