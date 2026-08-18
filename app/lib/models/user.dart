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
  final String? profilePhotoUrl;
  final List<String> serviceAreas;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    this.city,
    this.bio,
    this.approved = true,
    this.profilePhotoUrl,
    this.serviceAreas = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final profile = json['professional_profile'] as Map<String, dynamic>?;

    return AppUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      type: accountTypeFromApi(json['type']?.toString()),
      city: json['city']?.toString(),
      bio: json['bio']?.toString(),
      approved: json['status'] != null
          ? json['status'].toString() == 'ativo'
          : json['approved'] == true || json['approved'] == 1,
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      serviceAreas: (profile?['service_areas'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? bio,
    bool? approved,
    String? profilePhotoUrl,
    List<String>? serviceAreas,
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
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      serviceAreas: serviceAreas ?? this.serviceAreas,
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
