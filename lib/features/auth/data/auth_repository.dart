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
  }) async {
    final data = await _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role.key,
    });
    return AuthResult.fromJson(asMap(data));
  }

  /// Hoy responde 501 hasta que el backend tenga `GOOGLE_CLIENT_ID`.
  Future<AuthResult> google(String idToken) async {
    final data = await _api.post('/auth/google', body: {'id_token': idToken});
    return AuthResult.fromJson(asMap(data));
  }

  Future<User> me() async => User.fromJson(asMap(await _api.get('/auth/me')));
}
