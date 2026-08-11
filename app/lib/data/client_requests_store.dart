import 'package:flutter/foundation.dart';

import '../models/service_request.dart';
import '../services/api_exception.dart';
import '../services/service_request_service.dart';

/// Estado compartilhado das solicitações do cliente (Módulo 1).
class ClientRequestsStore extends ChangeNotifier {
  ClientRequestsStore._();
  static final ClientRequestsStore instance = ClientRequestsStore._();

  final _service = ServiceRequestService.instance;

  List<ServiceRequest> requests = [];
  bool loading = false;
  String? error;

  int get pendingCount =>
      requests.where((r) => r.status == ServiceStatus.pending).length;

  int get inProgressCount =>
      requests.where((r) => r.status == ServiceStatus.inProgress).length;

  int get completedCount =>
      requests.where((r) => r.status == ServiceStatus.completed).length;

  int get totalCount => requests.length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      requests = await _service.list();
    } on ApiException catch (e) {
      error = e.displayMessage;
    } catch (_) {
      error = 'Não foi possível carregar os serviços.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    requests = [];
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<ServiceRequest> create(CreateServiceRequestInput input) async {
    final created = await _service.create(input);
    requests = [created, ...requests];
    notifyListeners();
    return created;
  }
}
