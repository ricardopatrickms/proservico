import '../models/service_request.dart';
import 'api_client.dart';

class ServiceProposalService {
  ServiceProposalService._();
  static final ServiceProposalService instance = ServiceProposalService._();

  final _api = ApiClient.instance;

  Future<ServiceProposal> create({
    required String serviceRequestId,
    required double amount,
    required String message,
  }) async {
    final data = await _api.post(
      '/service-requests/$serviceRequestId/proposals',
      auth: true,
      body: {
        'amount': amount,
        'message': message,
      },
    );
    return ServiceProposal.fromJson(data);
  }

  Future<List<ServiceProposal>> list(String serviceRequestId) async {
    final data = await _api.getList(
      '/service-requests/$serviceRequestId/proposals',
      auth: true,
    );
    return data
        .whereType<Map>()
        .map((e) => ServiceProposal.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ServiceProposal> updateStatus({
    required String serviceRequestId,
    required String proposalId,
    required String status,
  }) async {
    final data = await _api.patch(
      '/service-requests/$serviceRequestId/proposals/$proposalId/status',
      auth: true,
      body: {'status': status},
    );
    return ServiceProposal.fromJson(data);
  }
}
