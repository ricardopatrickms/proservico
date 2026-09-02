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
        .whereType<Map>()
        .map((e) => UserAddress.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<UserAddress> create(UserAddressInput input) async {
    final data = await _api.post(
      '/user-addresses',
      auth: true,
      body: input.toJson(),
    );
    final addressJson = data['address'];
    if (addressJson is! Map) {
      throw const ApiException('Resposta inválida da API');
    }
    return UserAddress.fromJson(Map<String, dynamic>.from(addressJson));
  }

  Future<UserAddress> update({
    required String id,
    required UserAddressInput input,
  }) async {
    final data = await _api.put(
      '/user-addresses/$id',
      auth: true,
      body: input.toJson(),
    );
    final addressJson = data['address'];
    if (addressJson is! Map) {
      throw const ApiException('Resposta inválida da API');
    }
    return UserAddress.fromJson(Map<String, dynamic>.from(addressJson));
  }

  Future<void> delete(String id) async {
    await _api.delete('/user-addresses/$id', auth: true);
  }
}
