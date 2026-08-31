import '../models/service_request.dart';
import 'api_client.dart';

class ProfessionalServiceService {
  ProfessionalServiceService._();
  static final ProfessionalServiceService instance = ProfessionalServiceService._();

  final _api = ApiClient.instance;

  Future<List<ProfessionalService>> list() async {
    final data = await _api.getList('/professional-services', auth: true);
    return data
        .whereType<Map>()
        .map((e) => ProfessionalService.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ProfessionalService> create({
    required String title,
    required String category,
    required String description,
    required double priceFrom,
    bool active = true,
  }) async {
    final data = await _api.post(
      '/professional-services',
      auth: true,
      body: {
        'title': title,
        'category': category,
        'description': description,
        'price_from': priceFrom,
        'active': active,
      },
    );
    return ProfessionalService.fromJson(data);
  }

  Future<ProfessionalService> update(
    String id, {
    String? title,
    String? category,
    String? description,
    double? priceFrom,
    bool? active,
  }) async {
    final data = await _api.put(
      '/professional-services/$id',
      auth: true,
      body: {
        if (title != null) 'title': title,
        if (category != null) 'category': category,
        if (description != null) 'description': description,
        if (priceFrom != null) 'price_from': priceFrom,
        if (active != null) 'active': active,
      },
    );
    return ProfessionalService.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _api.delete('/professional-services/$id', auth: true);
  }
}
