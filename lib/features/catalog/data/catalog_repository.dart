import '../../../core/network/api_client.dart';
import '../domain/product.dart';

/// Catalogo publico: no necesita token.
///
/// ponytail: sin cache ni interfaz abstracta. La cascada marca -> modelo -> año
/// se pide al backend en cada cambio porque son tres listas de texto que tardan
/// menos que dibujar el desplegable; poner cache cuando se note.
class CatalogRepository {
  const CatalogRepository(this._api);

  final ApiClient _api;

  Future<List<String>> motoBrands() async =>
      (await _api.get('/catalog/moto-brands') as List).cast<String>();

  Future<List<String>> motoModels(String motoBrand) async =>
      (await _api.get('/catalog/moto-models', query: {'moto_brand': motoBrand})
              as List)
          .cast<String>();

  Future<List<int>> motoYears(String motoBrand, String motoModel) async =>
      (await _api.get('/catalog/moto-years', query: {
        'moto_brand': motoBrand,
        'moto_model': motoModel,
      }) as List)
          .cast<int>();

  Future<ProductPage> products({
    String? q,
    String? category,
    String? brand,
    String? partCode,
    String? motoBrand,
    String? motoModel,
    int? year,
    int? storeId,
    bool? onlyInStock,
    String orderBy = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get('/catalog/products', query: {
      'q': q,
      'category': category,
      'brand': brand,
      'part_code': partCode,
      'moto_brand': motoBrand,
      'moto_model': motoModel,
      'year': year,
      'store_id': storeId,
      'only_in_stock': onlyInStock,
      'order_by': orderBy,
      'limit': limit,
      'offset': offset,
    });
    return ProductPage.fromJson(asMap(data));
  }

  /// Detalle + `offers`: la misma pieza en otras tiendas, ya ordenada por
  /// precio y luego por distancia.
  Future<Product> product(int id) async =>
      Product.fromJson(asMap(await _api.get('/catalog/products/$id')));
}
