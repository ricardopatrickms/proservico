import '../models/service_request.dart';
import '../widgets/credit_card_payment_sheet.dart';
import 'api_client.dart';

class ServiceProposalService {
  ServiceProposalService._();
  static final ServiceProposalService instance = ServiceProposalService._();

  final _api = ApiClient.instance;

  Future<ServiceProposal> create({
    required String serviceRequestId,
    required double amount,
  }) async {
    final data = await _api.post(
      '/service-requests/$serviceRequestId/proposals',
      auth: true,
      body: {
        'amount': amount,
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
    String? billingType,
    String? cpf,
    CreditCardFormData? creditCard,
  }) async {
    final data = await _api.patch(
      '/service-requests/$serviceRequestId/proposals/$proposalId/status',
      auth: true,
      body: {
        'status': status,
        if (billingType != null) 'billing_type': billingType,
        if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
        if (creditCard != null) 'credit_card': creditCard.toJson(),
      },
    );
    return ServiceProposal.fromJson(data);
  }

  Future<ServicePayment> fetchPayment({
    required String serviceRequestId,
    required String proposalId,
    bool renew = false,
  }) async {
    final query = renew ? '?renew=1' : '';
    final data = await _api.get(
      '/service-requests/$serviceRequestId/proposals/$proposalId/payment$query',
      auth: true,
    );
    return ServicePayment.fromJson(data);
  }
}
