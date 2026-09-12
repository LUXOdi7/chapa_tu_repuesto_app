/// Perfiles del marketplace, tal como los nombra el backend.
/// - [buyer]    : mecánico independiente o motociclista final.
/// - [supplier] : tienda de autopartes; publica repuestos y despacha pedidos.
enum UserRole {
  buyer('buyer', 'Comprador', 'Mecánico o motociclista que compra repuestos'),
  supplier('supplier', 'Proveedor', 'Tienda de autopartes que publica y despacha');

  const UserRole(this.key, this.label, this.hint);

  /// Valor exacto que viaja en el JSON.
  final String key;
  final String label;
  final String hint;

  static UserRole parse(String? value) => UserRole.values.firstWhere(
        (r) => r.key == value,
        orElse: () => UserRole.buyer,
      );
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;

  bool get isSupplier => role == UserRole.supplier;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        role: UserRole.parse(json['role'] as String?),
      );
}

/// Respuesta comun de `/auth/login`, `/auth/register` y `/auth/google`.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['access_token'] as String,
        user: User.fromJson((json['user'] as Map).cast<String, dynamic>()),
      );
}
