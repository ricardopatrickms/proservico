import '../models/service_category.dart';
import 'api_client.dart';

class ServiceCategoryService {
  ServiceCategoryService._();
  static final ServiceCategoryService instance = ServiceCategoryService._();

  final _api = ApiClient.instance;

  Future<List<ServiceCategory>> list() async {
    final data = await _api.getList('/service-categories');
    return data
        .whereType<Map<String, dynamic>>()
        .map(ServiceCategory.fromJson)
        .where((c) => c.name.isNotEmpty)
        .toList();
  }

  List<String> parentNames(List<ServiceCategory> roots) {
    return [
      for (final root in roots)
        if (root.name.isNotEmpty) root.name,
    ];
  }
}
