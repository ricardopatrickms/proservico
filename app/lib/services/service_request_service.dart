import '../models/service_request.dart';
import 'api_client.dart';

class CreateServiceRequestInput {
  final String title;
  final String category;
  final String description;
  final String address;
  final String city;
  final String state;
  final String cep;
  final String? referencePoint;
  final DateTime preferredDate;
  final PreferredPeriod preferredPeriod;
  final double? budgetMin;
  final double? budgetMax;
  final bool acceptsNegotiation;
  final String materialsResponsible;
  final String? materialsDetails;
  final ServiceUrgency urgency;
  final bool prefersGoodRatings;
  final GenderPreference genderPreference;
  final List<String> photoPaths;

  const CreateServiceRequestInput({
    required this.title,
    required this.category,
    required this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.cep,
    this.referencePoint,
    required this.preferredDate,
    required this.preferredPeriod,
    this.budgetMin,
    this.budgetMax,
    required this.acceptsNegotiation,
    required this.materialsResponsible,
    this.materialsDetails,
    required this.urgency,
    required this.prefersGoodRatings,
    required this.genderPreference,
    required this.photoPaths,
  });

  Map<String, String> toMultipartFields() {
    final scheduledAt = DateTime(
      preferredDate.year,
      preferredDate.month,
      preferredDate.day,
      preferredPeriod.startHour,
    );

    final location = [
      address,
      city,
      state,
      cep,
    ].where((e) => e.trim().isNotEmpty).join(' - ');

    final preferences = [
      prefersGoodRatings
          ? 'Prefere profissional com boas avaliações'
          : 'Avaliações não são prioritárias',
      'Gênero: ${switch (genderPreference) {
        GenderPreference.any => 'sem preferência',
        GenderPreference.male => 'masculino',
        GenderPreference.female => 'feminino',
      }}',
      if (referencePoint != null && referencePoint!.trim().isNotEmpty)
        'Referência: ${referencePoint!.trim()}',
      if (materialsDetails != null && materialsDetails!.trim().isNotEmpty)
        'Materiais: ${materialsDetails!.trim()}',
    ].join(' | ');

    return {
      'title': title,
      'category': category,
      'description': description,
      'location': location,
      'address': address,
      'city': city,
      'state': state,
      'cep': cep,
      if (referencePoint != null && referencePoint!.trim().isNotEmpty)
        'reference_point': referencePoint!.trim(),
      'scheduled_at': scheduledAt.toIso8601String(),
      'preferred_period': preferredPeriod.apiValue,
      if (budgetMin != null) 'budget_min': budgetMin!.toString(),
      if (budgetMax != null) 'budget_max': budgetMax!.toString(),
      if (budgetMax != null || budgetMin != null)
        'budget': (budgetMax ?? budgetMin)!.toString(),
      'accepts_negotiation': acceptsNegotiation ? '1' : '0',
      'materials_responsible': materialsResponsible,
      if (materialsDetails != null && materialsDetails!.trim().isNotEmpty)
        'materials_details': materialsDetails!.trim(),
      'needs_materials': materialsResponsible != 'client' ? '1' : '0',
      'urgency': urgency.apiValue,
      'preferences': preferences,
      'prefers_good_ratings': prefersGoodRatings ? '1' : '0',
      'gender_preference': genderPreference.apiValue,
    };
  }
}

class ServiceRequestService {
  ServiceRequestService._();
  static final ServiceRequestService instance = ServiceRequestService._();

  final _api = ApiClient.instance;

  Future<List<ServiceRequest>> list() async {
    final data = await _api.getList('/service-requests', auth: true);
    return data
        .whereType<Map>()
        .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ServiceRequest> create(CreateServiceRequestInput input) async {
    final data = await _api.postMultipart(
      '/service-requests',
      auth: true,
      fields: input.toMultipartFields(),
      fileLists: {
        'photos': input.photoPaths,
      },
    );
    return ServiceRequest.fromJson(data);
  }

  Future<ServiceRequest> updateStatus(
    String id, {
    required String status,
    String? professionalId,
  }) async {
    final data = await _api.patch(
      '/service-requests/$id/status',
      auth: true,
      body: {
        'status': status,
        if (professionalId != null) 'professional_id': professionalId,
      },
    );
    return ServiceRequest.fromJson(data);
  }
}
