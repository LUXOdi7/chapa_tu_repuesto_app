import '../../../core/format.dart';

/// Perfiles del marketplace, tal como los nombra el backend.
/// - [buyer]    : mecánico independiente o motociclista final.
/// - [supplier] : tienda de autopartes; publica repuestos y despacha pedidos.
///                También puede comprar ("modo comprador").
/// - [admin]    : gestiona cuentas, verifica tiendas y lee sugerencias.
///                No se registra desde la app (`ctr admin correo clave`).
enum UserRole {
  buyer('buyer', 'Comprador', 'Mecánico o motociclista que compra repuestos'),
  supplier(
    'supplier',
    'Proveedor',
    'Tienda de autopartes que publica y despacha',
  ),
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
    this.buyerRatingAvg = 0,
    this.buyerRatingCount = 0,
    this.address,
    this.latitude,
    this.longitude,
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

  /// Reputación como comprador (la tienda lo califica al entregar).
  final double buyerRatingAvg;
  final int buyerRatingCount;

  /// Dirección de entrega guardada (se reusa en el checkout) y su punto en el
  /// mapa; ambos opcionales.
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasSavedAddress => address != null && address!.isNotEmpty;

  String get buyerRatingLabel => buyerRatingCount == 0
      ? 'Sin calificaciones como comprador'
      : '${buyerRatingAvg.toStringAsFixed(1)} ★ como comprador ($buyerRatingCount)';

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
    buyerRatingAvg: (json['buyer_rating_avg'] as num?)?.toDouble() ?? 0,
    buyerRatingCount: json['buyer_rating_count'] as int? ?? 0,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

/// Moto guardada por el comprador ("Mis motos").
class UserMoto {
  const UserMoto({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    this.type = 'lineal',
  });

  final int id;

  /// lineal (2 ruedas) · carguero (tolva) · mototaxi (cabina).
  final String type;
  final String brand;
  final String model;
  final int year;

  String get label => '$brand $model $year';

  /// "Mototaxi · Bajaj RE 4S Torito 2019"
  String get fullLabel => '${motoTypeLabel(type)} · $label';

  factory UserMoto.fromJson(Map<String, dynamic> json) => UserMoto(
    id: json['id'] as int,
    type: json['moto_type'] as String? ?? 'lineal',
    brand: json['moto_brand'] as String? ?? '',
    model: json['moto_model'] as String? ?? '',
    year: json['year'] as int? ?? 0,
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
