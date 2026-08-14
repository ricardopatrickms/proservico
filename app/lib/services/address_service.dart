import '../models/user_address.dart';
import 'api_client.dart';
import 'api_exception.dart';

class AddressService {
  AddressService._();
  static final AddressService instance = AddressService._();

  final _api = ApiClient.instance;

  Future<List<UserAddress>> list() async {
    final data = await _api.getList('/user-addresses', auth: true);
    return data
        .whereType<Map<String, dynamic>>()
        .map(UserAddress.fromJson)
        .toList();
  }

  Future<UserAddress> create({
    required String label,
    required String details,
  }) async {
    final data = await _api.post(
      '/user-addresses',
      auth: true,
      body: {
        'label': label,
        'details': details,
      },
    );
    final addressJson = data['address'];
    if (addressJson is! Map<String, dynamic>) {
      throw const ApiException('Resposta inválida da API');
    }
    return UserAddress.fromJson(addressJson);
  }

  Future<UserAddress> update({
    required String id,
    required String label,
    required String details,
  }) async {
    final data = await _api.put(
      '/user-addresses/$id',
      auth: true,
      body: {
        'label': label,
        'details': details,
      },
    );
    final addressJson = data['address'];
    if (addressJson is! Map<String, dynamic>) {
      throw const ApiException('Resposta inválida da API');
    }
    return UserAddress.fromJson(addressJson);
  }

  Future<void> delete(String id) async {
    await _api.delete('/user-addresses/$id', auth: true);
  }
}
