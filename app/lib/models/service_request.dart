enum ServiceUrgency { normal, urgent, emergency }

enum ServiceStatus { pending, inProgress, completed, cancelled }

enum PreferredPeriod { morning, afternoon, evening, business }

enum GenderPreference { any, male, female }

class ServiceRequest {
  final String id;
  final String title;
  final String? category;
  final String description;
  final String location;
  final String? address;
  final String? city;
  final String? state;
  final String? cep;
  final String? referencePoint;
  final DateTime scheduledAt;
  final PreferredPeriod? preferredPeriod;
  final double? budget;
  final double? budgetMin;
  final double? budgetMax;
  final bool acceptsNegotiation;
  final bool needsMaterials;
  final String? materialsResponsible;
  final String? materialsDetails;
  final ServiceUrgency urgency;
  final String preferences;
  final bool? prefersGoodRatings;
  final GenderPreference? genderPreference;
  final List<String> photoLabels;
  final List<String> photoUrls;
  final ServiceStatus status;
  final String? professionalName;
  final DateTime? createdAt;
  final List<ServiceProposal> proposals;

  const ServiceRequest({
    required this.id,
    required this.title,
    this.category,
    required this.description,
    required this.location,
    this.address,
    this.city,
    this.state,
    this.cep,
    this.referencePoint,
    required this.scheduledAt,
    this.preferredPeriod,
    this.budget,
    this.budgetMin,
    this.budgetMax,
    this.acceptsNegotiation = true,
    this.needsMaterials = false,
    this.materialsResponsible,
    this.materialsDetails,
    this.urgency = ServiceUrgency.normal,
    this.preferences = '',
    this.prefersGoodRatings,
    this.genderPreference,
    this.photoLabels = const [],
    this.photoUrls = const [],
    this.status = ServiceStatus.pending,
    this.professionalName,
    this.createdAt,
    this.proposals = const [],
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    final professional = json['professional'];
    final urls = (json['photo_urls'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final photos = (json['photos'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    return ServiceRequest(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString(),
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      cep: json['cep']?.toString(),
      referencePoint: json['reference_point']?.toString(),
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? '') ??
          DateTime.now(),
      preferredPeriod: preferredPeriodFromApi(json['preferred_period']?.toString()),
      budget: _toDouble(json['budget']),
      budgetMin: _toDouble(json['budget_min']),
      budgetMax: _toDouble(json['budget_max']),
      acceptsNegotiation:
          json['accepts_negotiation'] == true || json['accepts_negotiation'] == 1,
      needsMaterials: json['needs_materials'] == true || json['needs_materials'] == 1,
      materialsResponsible: json['materials_responsible']?.toString(),
      materialsDetails: json['materials_details']?.toString(),
      urgency: serviceUrgencyFromApi(json['urgency']?.toString()),
      preferences: json['preferences']?.toString() ?? '',
      prefersGoodRatings: json['prefers_good_ratings'] == null
          ? null
          : (json['prefers_good_ratings'] == true || json['prefers_good_ratings'] == 1),
      genderPreference: genderPreferenceFromApi(json['gender_preference']?.toString()),
      photoLabels: (json['photo_labels'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      photoUrls: urls.isNotEmpty ? urls : photos,
      status: serviceStatusFromApi(json['status']?.toString()),
      professionalName: professional is Map
          ? professional['name']?.toString()
          : json['professional_name']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      proposals: (json['proposals'] as List?)
              ?.whereType<Map>()
              .map((e) => ServiceProposal.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }

  String get cityStateLabel {
    final parts = [
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return location;
  }

  String? get budgetRangeLabel {
    if (budgetMin != null && budgetMax != null) {
      return '${_money(budgetMin!)} - ${_money(budgetMax!)}';
    }
    if (budgetMax != null) return _money(budgetMax!);
    if (budgetMin != null) return _money(budgetMin!);
    if (budget != null) return _money(budget!);
    return null;
  }

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $fixed';
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

ServiceStatus serviceStatusFromApi(String? value) {
  switch (value) {
    case 'in_progress':
      return ServiceStatus.inProgress;
    case 'completed':
      return ServiceStatus.completed;
    case 'cancelled':
      return ServiceStatus.cancelled;
    default:
      return ServiceStatus.pending;
  }
}

ServiceUrgency serviceUrgencyFromApi(String? value) {
  switch (value) {
    case 'urgent':
      return ServiceUrgency.urgent;
    case 'emergency':
      return ServiceUrgency.emergency;
    default:
      return ServiceUrgency.normal;
  }
}

PreferredPeriod? preferredPeriodFromApi(String? value) {
  switch (value) {
    case 'morning':
      return PreferredPeriod.morning;
    case 'afternoon':
      return PreferredPeriod.afternoon;
    case 'evening':
      return PreferredPeriod.evening;
    case 'business':
      return PreferredPeriod.business;
    default:
      return null;
  }
}

GenderPreference? genderPreferenceFromApi(String? value) {
  switch (value) {
    case 'male':
      return GenderPreference.male;
    case 'female':
      return GenderPreference.female;
    case 'any':
      return GenderPreference.any;
    default:
      return null;
  }
}

extension ServiceUrgencyApi on ServiceUrgency {
  String get apiValue => switch (this) {
        ServiceUrgency.normal => 'normal',
        ServiceUrgency.urgent => 'urgent',
        ServiceUrgency.emergency => 'emergency',
      };
}

extension PreferredPeriodApi on PreferredPeriod {
  String get apiValue => switch (this) {
        PreferredPeriod.morning => 'morning',
        PreferredPeriod.afternoon => 'afternoon',
        PreferredPeriod.evening => 'evening',
        PreferredPeriod.business => 'business',
      };

  String get label => switch (this) {
        PreferredPeriod.morning => 'Manhã',
        PreferredPeriod.afternoon => 'Tarde',
        PreferredPeriod.evening => 'Noite',
        PreferredPeriod.business => 'Horário comercial',
      };

  String get subtitle => switch (this) {
        PreferredPeriod.morning => '08:00 - 12:00',
        PreferredPeriod.afternoon => '13:00 - 18:00',
        PreferredPeriod.evening => '18:00 - 22:00',
        PreferredPeriod.business => '08:00 - 18:00',
      };

  int get startHour => switch (this) {
        PreferredPeriod.morning => 8,
        PreferredPeriod.afternoon => 13,
        PreferredPeriod.evening => 18,
        PreferredPeriod.business => 8,
      };
}

extension GenderPreferenceApi on GenderPreference {
  String get apiValue => switch (this) {
        GenderPreference.any => 'any',
        GenderPreference.male => 'male',
        GenderPreference.female => 'female',
      };
}

enum ProposalStatus { pending, accepted, rejected, withdrawn }

class ServiceProposal {
  final String id;
  final String serviceRequestId;
  final String professionalId;
  final String professionalName;
  final double amount;
  final String message;
  final ProposalStatus status;
  final DateTime createdAt;

  const ServiceProposal({
    required this.id,
    required this.serviceRequestId,
    required this.professionalId,
    required this.professionalName,
    required this.amount,
    required this.message,
    this.status = ProposalStatus.pending,
    required this.createdAt,
  });

  factory ServiceProposal.fromJson(Map<String, dynamic> json) {
    final professional = json['professional'];
    return ServiceProposal(
      id: json['id'].toString(),
      serviceRequestId: json['service_request_id']?.toString() ?? '',
      professionalId: json['professional_id']?.toString() ??
          (professional is Map ? professional['id']?.toString() ?? '' : ''),
      professionalName: professional is Map
          ? professional['name']?.toString() ?? 'Profissional'
          : json['professional_name']?.toString() ?? 'Profissional',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      message: json['message']?.toString() ?? '',
      status: proposalStatusFromApi(json['status']?.toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get statusLabel => switch (status) {
        ProposalStatus.pending => 'Pendente',
        ProposalStatus.accepted => 'Aceita',
        ProposalStatus.rejected => 'Recusada',
        ProposalStatus.withdrawn => 'Retirada',
      };
}

ProposalStatus proposalStatusFromApi(String? value) {
  switch (value) {
    case 'accepted':
      return ProposalStatus.accepted;
    case 'rejected':
      return ProposalStatus.rejected;
    case 'withdrawn':
      return ProposalStatus.withdrawn;
    default:
      return ProposalStatus.pending;
  }
}

class ProfessionalService {
  final String id;
  final String title;
  final String category;
  final String description;
  final double priceFrom;
  final bool active;

  const ProfessionalService({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.priceFrom,
    this.active = true,
  });

  ProfessionalService copyWith({
    String? title,
    String? category,
    String? description,
    double? priceFrom,
    bool? active,
  }) {
    return ProfessionalService(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      priceFrom: priceFrom ?? this.priceFrom,
      active: active ?? this.active,
    );
  }
}
