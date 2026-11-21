import '../../../core/network/api_client.dart';
import '../../auth/domain/user.dart';
import '../../catalog/domain/store.dart';
import '../../orders/domain/order.dart';

/// Panel del administrador. Todo requiere token con perfil `admin`.
class AdminRepository {
  const AdminRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> stats() async =>
      asMap(await _api.get('/admin/stats'));

  Future<List<User>> users({
    String? q,
    UserRole? role,
    bool onlyInactive = false,
  }) async => asMapList(
    asMap(
      await _api.get(
        '/admin/users',
        query: {
          'q': q,
          'role': role?.key,
          'only_inactive': onlyInactive ? true : null,
          'limit': 200,
        },
      ),
    )['items'],
  ).map(User.fromJson).toList();

  Future<User> updateUser(int id, {bool? isActive, UserRole? role}) async =>
      User.fromJson(
        asMap(
          await _api.patch(
            '/admin/users/$id',
            body: {'is_active': isActive, 'role': role?.key},
          ),
        ),
      );

  Future<List<Store>> stores({bool onlyPending = false}) async => asMapList(
    await _api.get(
      '/admin/stores',
      query: {'only_pending': onlyPending ? true : null},
    ),
  ).map(Store.fromJson).toList();

  Future<Store> verifyStore(int id, bool verified) async => Store.fromJson(
    asMap(await _api.patch('/admin/stores/$id', body: {'verified': verified})),
  );

  Future<void> extendSubscription(int storeId) =>
      _api.patch('/admin/stores/$storeId/subscription');

  Future<List<Order>> orders({String? statusFilter}) async => asMapList(
    await _api.get('/admin/orders', query: {'status_filter': statusFilter}),
  ).map(Order.fromJson).toList();

  Future<List<Map<String, dynamic>>> feedback({bool onlyOpen = true}) async =>
      asMapList(
        await _api.get('/admin/feedback', query: {'only_open': onlyOpen}),
      );

  Future<void> resolveFeedback(int id) => _api.patch('/admin/feedback/$id');

  Future<List<Map<String, dynamic>>> reclamaciones({bool? resuelto}) async =>
      asMapList(
        await _api.get(
          '/admin/reclamaciones',
          query: {'resuelto': resuelto},
        ),
      );

  Future<void> responderReclamacion(
    int id, {
    required String respuesta,
    required bool resuelto,
  }) => _api.patch(
    '/admin/reclamaciones/$id',
    body: {'respuesta': respuesta, 'resuelto': resuelto},
  );

  // ---- Movimientos de pago ----
  Future<Map<String, dynamic>> movements({
    String? dateFrom,
    String? dateTo,
    String? buyerEmail,
    int? storeId,
  }) async => asMap(
    await _api.get('/admin/movements', query: {
      'date_from': dateFrom,
      'date_to': dateTo,
      'buyer_email': buyerEmail,
      'store_id': storeId,
    }),
  );

  // ---- Registros de usuarios ----
  Future<Map<String, dynamic>> registrations({
    String? dateFrom,
    String? dateTo,
    String? role,
  }) async => asMap(
    await _api.get('/admin/registrations', query: {
      'date_from': dateFrom,
      'date_to': dateTo,
      'role': role,
    }),
  );

  // ---- Chat directo con proveedores ----
  Future<List<Map<String, dynamic>>> directConversations() async =>
      asMapList(await _api.get('/admin/direct-conversations'));

  Future<List<DirectChatMessage>> directMessages(
    int userId, {
    int afterId = 0,
  }) async => asMapList(
    await _api.get(
      '/admin/direct-messages/$userId',
      query: {'after_id': afterId > 0 ? afterId : null},
    ),
  ).map(DirectChatMessage.fromJson).toList();

  Future<DirectChatMessage> sendDirectMessage(
    int userId,
    String body, {
    String? imageUrl,
  }) async => DirectChatMessage.fromJson(
    asMap(
      await _api.post(
        '/admin/direct-messages/$userId',
        body: {'body': body, 'image_url': imageUrl},
      ),
    ),
  );
}
