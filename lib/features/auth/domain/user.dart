/// Perfiles del marketplace, tal como los nombra el backend.
/// - [buyer]    : mecánico independiente o motociclista final.
/// - [supplier] : tienda de autopartes; publica repuestos y despacha pedidos.
///                También puede comprar ("modo comprador").
/// - [admin]    : gestiona cuentas, verifica tiendas y lee sugerencias.
///                No se registra desde la app (`ctr admin correo clave`).
enum UserRole {
  buyer('buyer', 'Comprador', 'Mecánico o motociclista que compra repuestos'),
  supplier('supplier', 'Proveedor', 'Tienda de autopartes que publica y despacha'),
  admin('admin', 'Administrador', 'Gestiona la plataforma');

  const UserRole(this.key, this.label, this.hint);

  /// Valor exacto que viaja en el JSON.
  final String key;
  final String label;
  final String hint;

  static UserRole parse(String? value) => UserRole.values.firstWhere(
        (r) => r.key == value,
        orElse: () => UserRole.buyer,
      );

  /// Los que se pueden elegir al registrarse.
  static const registrable = [UserRole.buyer, UserRole.supplier];
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
    this.storeId,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;
  final UserRole role;

  /// Solo para proveedores: null si todavía no registró su tienda.
  final int? storeId;

  bool get isSupplier => role == UserRole.supplier;
  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        role: UserRole.parse(json['role'] as String?),
        storeId: json['store_id'] as int?,
      );
}

/// Respuesta comun de `/auth/login`, `/auth/register`, `/auth/google` y `/auth/reset`.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['access_token'] as String,
        user: User.fromJson((json['user'] as Map).cast<String, dynamic>()),
      );
}
