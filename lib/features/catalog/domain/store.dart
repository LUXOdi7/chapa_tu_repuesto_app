import '../../../core/network/api_client.dart';

/// Tienda de autopartes.
///
/// El backend la devuelve en tres tamaños distintos: resumida dentro de cada
/// producto, completa en `/catalog/stores/{id}` (+ ruc, direccion, horario,
/// descripcion) y minima dentro de un pedido. Un solo modelo con casi todo
/// opcional evita tres clases que solo se diferencian en cuantos nulls traen.
class Store {
  const Store({
    required this.id,
    required this.businessName,
    this.district,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.verified = false,
    this.ruc,
    this.description,
    this.address,
    this.phone,
    this.openingHours,
    this.logoUrl,
    this.paymentProvider,
    this.paymentConfigured = false,
    this.productCount,
    this.ownerEmail,
    this.subscriptionActive = false,
    this.subscriptionDaysLeft = -999,
  });

  final int id;
  final String businessName;
  final String? district;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final double ratingAvg;
  final int ratingCount;
  final bool verified;
  final String? ruc;
  final String? description;
  final String? address;
  final String? phone;
  final String? openingHours;
  final String? logoUrl;

  /// `simulado` | `mercadopago` | `niubiz`.
  final String? paymentProvider;

  /// Solo en el panel del proveedor: si ya cargó credenciales de cobro.
  final bool paymentConfigured;
  final int? productCount;

  /// Solo en el panel admin: correo del dueño de la tienda.
  final String? ownerEmail;

  /// Suscripción mensual (S/ 100): activa si `subscription_paid_until` > hoy.
  /// `subscriptionDaysLeft` < 0 = expiró hace N días; -999 = nunca activada.
  final bool subscriptionActive;
  final int subscriptionDaysLeft;

  bool get hasLocation => latitude != null && longitude != null;

  String get distanceLabel =>
      distanceKm == null ? '' : '${distanceKm!.toStringAsFixed(1)} km';

  String get ratingLabel => ratingCount == 0
      ? 'Sin calificaciones'
      : '${ratingAvg.toStringAsFixed(1)} ★ ($ratingCount)';

  factory Store.fromJson(Map<String, dynamic> json) => Store(
    id: json['id'] as int,
    businessName: json['business_name'] as String? ?? 'Tienda',
    district: json['district'] as String?,
    distanceKm: asDouble(json['distance_km']),
    latitude: asDouble(json['latitude']),
    longitude: asDouble(json['longitude']),
    ratingAvg: asDouble(json['rating_avg']) ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
    verified: json['verified'] as bool? ?? false,
    ruc: json['ruc'] as String?,
    description: json['description'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    openingHours: json['opening_hours'] as String?,
    logoUrl: json['logo_url'] as String?,
    paymentProvider: json['payment_provider'] as String?,
    paymentConfigured: json['payment_configured'] as bool? ?? false,
    productCount: json['product_count'] as int?,
    ownerEmail: (json['owner'] as Map?)
        ?.cast<String, dynamic>()['email'] as String?,
    subscriptionActive: json['subscription_active'] as bool? ?? false,
    subscriptionDaysLeft: json['subscription_days_left'] as int? ?? -999,
  );

  /// Solo lo que necesita el carrito persistido para volver a dibujarse.
  Map<String, dynamic> toJson() => {
    'id': id,
    'business_name': businessName,
    'district': district,
    'distance_km': distanceKm,
    'latitude': latitude,
    'longitude': longitude,
    'rating_avg': ratingAvg,
    'rating_count': ratingCount,
    'verified': verified,
    'phone': phone,
    'address': address,
    'payment_provider': paymentProvider,
  };
}

/// Calificación recibida por una tienda.
class StoreReview {
  const StoreReview({
    required this.rating,
    required this.comment,
    required this.buyerName,
  });

  final int rating;
  final String comment;
  final String buyerName;

  factory StoreReview.fromJson(Map<String, dynamic> json) => StoreReview(
    rating: json['rating'] as int? ?? 0,
    comment: json['comment'] as String? ?? '',
    buyerName: json['buyer_name'] as String? ?? '',
  );
}
