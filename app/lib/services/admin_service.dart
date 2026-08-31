import '../models/service_request.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';

class AdminDashboardStats {
  final int clients;
  final int professionals;
  final int pendingApprovals;
  final int serviceRequests;

  const AdminDashboardStats({
    required this.clients,
    required this.professionals,
    required this.pendingApprovals,
    required this.serviceRequests,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      clients: (json['clients'] as num?)?.toInt() ?? 0,
      professionals: (json['professionals'] as num?)?.toInt() ?? 0,
      pendingApprovals: (json['pending_approvals'] as num?)?.toInt() ?? 0,
      serviceRequests: (json['service_requests'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final _api = ApiClient.instance;

  Future<AdminDashboardStats> dashboard() async {
    final data = await _api.get('/admin/dashboard', auth: true);
    return AdminDashboardStats.fromJson(data);
  }

  Future<List<AppUser>> users({String? type, bool? approved}) async {
    final params = <String, String>{
      if (type != null) 'type': type,
      if (approved != null) 'approved': approved ? '1' : '0',
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final data = await _api.getList('/admin/users$query', auth: true);
    return data
        .whereType<Map>()
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AppUser> setApproval(String id, {required bool approved}) async {
    final data = await _api.patch(
      '/admin/users/$id/approval',
      auth: true,
      body: {'approved': approved},
    );
    final userJson = data['user'];
    if (userJson is! Map) {
      throw const ApiException('Resposta inválida da API');
    }
    return AppUser.fromJson(Map<String, dynamic>.from(userJson));
  }

  Future<List<ServiceRequest>> serviceRequests() async {
    final data = await _api.getList('/admin/service-requests', auth: true);
    return data
        .whereType<Map>()
        .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
