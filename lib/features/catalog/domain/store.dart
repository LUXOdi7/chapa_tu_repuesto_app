/// Tienda de autopartes.
///
/// El backend la devuelve en tres tamaños distintos: resumida dentro de cada
/// producto (nombre, distrito, distancia, rating), completa en
/// `/catalog/stores/{id}` (+ ruc, direccion, horario) y minima dentro de un
/// pedido (nombre, telefono, direccion). Un solo modelo con casi todo opcional
/// evita tres clases que solo se diferencian en cuantos nulls traen.
class Store {
  const Store({
    required this.id,
    required this.businessName,
    this.district,
    this.distanceKm,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.verified = false,
    this.ruc,
    this.address,
    this.phone,
    this.openingHours,
    this.logoUrl,
  });

  final int id;
  final String businessName;
  final String? district;
  final double? distanceKm;
  final double ratingAvg;
  final int ratingCount;
  final bool verified;
  final String? ruc;
  final String? address;
  final String? phone;
  final String? openingHours;
  final String? logoUrl;

  String get distanceLabel =>
      distanceKm == null ? '' : '${distanceKm!.toStringAsFixed(1)} km';

  String get ratingLabel =>
      ratingCount == 0 ? 'Sin calificaciones' : '${ratingAvg.toStringAsFixed(1)} ★ ($ratingCount)';

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'] as int,
        businessName: json['business_name'] as String? ?? 'Tienda',
        district: json['district'] as String?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: json['rating_count'] as int? ?? 0,
        verified: json['verified'] as bool? ?? false,
        ruc: json['ruc'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        openingHours: json['opening_hours'] as String?,
        logoUrl: json['logo_url'] as String?,
      );

  /// Solo lo que necesita el carrito persistido para volver a dibujarse.
  Map<String, dynamic> toJson() => {
        'id': id,
        'business_name': businessName,
        'district': district,
        'distance_km': distanceKm,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'verified': verified,
        'phone': phone,
        'address': address,
      };
}
