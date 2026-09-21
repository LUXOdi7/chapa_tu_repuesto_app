import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/network/api_client.dart';
import '../../catalog/domain/compatibility.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/domain/store.dart';

/// Panel del proveedor. Todo requiere token con perfil `supplier`.
class SupplierRepository {
  const SupplierRepository(this._api);

  final ApiClient _api;

  /// `null` = todavia no registro su tienda (el backend responde 404). No es un
  /// error: la app lo lleva al formulario de registro.
  Future<Store?> myStore() async {
    try {
      return Store.fromJson(asMap(await _api.get('/suppliers/store')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Crea o actualiza la tienda. El RUC son exactamente 11 digitos y es unico.
  Future<Store> saveStore({
    required String businessName,
    required String ruc,
    required String address,
    required String district,
    required String phone,
    String? description,
    String? openingHours,
    String? logoUrl,
    double? distanceKm,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _api.post('/suppliers/store', body: {
      'business_name': businessName,
      'ruc': ruc,
      'description': description,
      'address': address,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'opening_hours': openingHours,
      'logo_url': logoUrl,
      'distance_km': distanceKm,
    });
    return Store.fromJson(asMap(data));
  }

  /// Afiliacion a la pasarela. `account`: token de Mercado Pago o
  /// "merchantId|usuario|clave" de Niubiz; null para modo simulado.
  Future<Store> configurePayment({required String provider, String? account}) async =>
      Store.fromJson(asMap(await _api.put('/suppliers/store/payment', body: {
        'payment_provider': provider,
        'payment_account': account,
      })));

  /// Resumen para la portada del panel (productos, pedidos por estado, ventas).
  Future<Map<String, dynamic>> dashboard() async => asMap(await _api.get('/suppliers/dashboard'));

  Future<List<Product>> myProducts() async =>
      asMapList(await _api.get('/suppliers/products'))
          .map(Product.fromJson)
          .toList();

  Future<Product> createProduct(Map<String, dynamic> body) async =>
      Product.fromJson(asMap(await _api.post('/suppliers/products', body: body)));

  /// El PUT reemplaza tambien las compatibilidades: hay que mandarlas todas.
  Future<Product> updateProduct(int id, Map<String, dynamic> body) async =>
      Product.fromJson(
          asMap(await _api.put('/suppliers/products/$id', body: body)));

  /// Baja logica.
  Future<void> deleteProduct(int id) => _api.delete('/suppliers/products/$id');

  /// Foto del repuesto -> `uploads/products/`. Devuelve la ruta relativa.
  Future<String> uploadImage(XFile file) => _api.uploadImage(file);

  /// Un producto CON sus compatibilidades (la lista no las trae): se usa
  /// antes de editar, si no el PUT las borraria.
  Future<Product> product(int id) async =>
      Product.fromJson(asMap(await _api.get('/suppliers/products/$id')));

  /// Cuerpo comun de POST y PUT de productos.
  static Map<String, dynamic> productBody({
    required String name,
    required String category,
    required String partCode,
    required double price,
    required int stock,
    String? brand,
    String? description,
    String? imageUrl,
    List<String> imageUrls = const [],
    int? warrantyMonths,
    bool isActive = true,
    List<Compatibility> compatibilities = const [],
  }) =>
      {
        'name': name,
        'category': category,
        'part_code': partCode,
        'brand': brand,
        'description': description,
        'image_url': imageUrl,
        'image_urls': imageUrls,
        'price': price,
        'stock': stock,
        'warranty_months': warrantyMonths,
        'is_active': isActive,
        'compatibilities': [for (final c in compatibilities) c.toJson()],
      };
}
