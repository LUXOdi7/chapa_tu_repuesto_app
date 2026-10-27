import '../../../core/network/api_client.dart';
import '../domain/user.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  /// OJO: este endpoint es form-urlencoded y el campo `username` es el CORREO.
  /// Mandarlo como JSON devuelve 422.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.postForm('/auth/login', {
      'username': email,
      'password': password,
    });
    return AuthResult.fromJson(asMap(data));
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    BuyerType? buyerType,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role.key,
        'buyer_type': buyerType?.key,
      },
    );
    return AuthResult.fromJson(asMap(data));
  }

  /// Responde 501 hasta que el backend tenga `GOOGLE_CLIENT_ID` (ver guía).
  Future<AuthResult> google(
    String idToken, {
    UserRole role = UserRole.buyer,
  }) async {
    final data = await _api.post(
      '/auth/google',
      body: {'id_token': idToken, 'role': role.key},
    );
    return AuthResult.fromJson(asMap(data));
  }

  /// Envía un código de 6 dígitos al correo (siempre responde 200).
  Future<void> forgot(String email) =>
      _api.post('/auth/forgot', body: {'email': email});

  /// Cambia la contraseña con el código y deja la sesión iniciada.
  Future<AuthResult> reset({
    required String email,
    required String code,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/reset',
      body: {'email': email, 'code': code, 'password': password},
    );
    return AuthResult.fromJson(asMap(data));
  }

  Future<User> me() async => User.fromJson(asMap(await _api.get('/auth/me')));

  Future<void> registerDeviceToken(String? fcmToken) async {
    await _api.put('/auth/me/device', body: {'fcm_token': fcmToken});
  }

  Future<User> updateProfile({
    String? name,
    String? phone,
    String? password,
    String? avatarUrl,
    String? address,
    double? latitude,
    double? longitude,
  }) async => User.fromJson(
    asMap(
      await _api.patch(
        '/auth/me',
        body: {
          'name': name,
          'phone': phone,
          'password': password,
          'avatar_url': avatarUrl,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        },
      ),
    ),
  );

  Future<void> sendFeedback({
    required String subject,
    required String message,
  }) => _api.post('/feedback', body: {'subject': subject, 'message': message});

  /// Libro de reclamaciones INDECOPI. No requiere sesion iniciada.
  Future<String> submitReclamacion({
    required String nombre,
    required String dni,
    required String direccion,
    required String telefono,
    required String correo,
    required String tipo,
    required String bienContratado,
    required String detalle,
    required String pedidoConsumidor,
    String numPedido = '',
  }) async {
    final data = await _api.post('/reclamaciones', body: {
      'nombre': nombre,
      'dni': dni,
      'direccion': direccion,
      'telefono': telefono,
      'correo': correo,
      'tipo': tipo,
      'bien_contratado': bienContratado,
      'num_pedido': numPedido,
      'detalle': detalle,
      'pedido_consumidor': pedidoConsumidor,
    });
    return asMap(data)['correlativo'] as String;
  }

  // ---- Mis motos ----
  Future<List<UserMoto>> motos() async =>
      asMapList(await _api.get('/auth/me/motos'))
          .map(UserMoto.fromJson)
          .toList();

  Future<UserMoto> addMoto({
    required String type,
    required String brand,
    required String model,
    required int year,
  }) async => UserMoto.fromJson(
    asMap(
      await _api.post(
        '/auth/me/motos',
        body: {
          'moto_type': type,
          'moto_brand': brand,
          'moto_model': model,
          'year': year,
        },
      ),
    ),
  );

  Future<void> deleteMoto(int id) => _api.delete('/auth/me/motos/$id');

  // ---- Notificaciones (campana) ----
  Future<List<Map<String, dynamic>>> notifications() async =>
      asMapList(asMap(await _api.get('/notifications'))['items']);

  Future<int> unreadNotifications() async =>
      asMap(await _api.get('/notifications/unread-count'))['unread'] as int? ??
      0;

  Future<void> markNotificationRead(int id) =>
      _api.patch('/notifications/$id/read');

  Future<void> markAllNotificationsRead() =>
      _api.post('/notifications/read-all');
}
