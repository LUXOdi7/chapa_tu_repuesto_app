import '../../../core/format.dart';
import '../../../core/network/api_client.dart';
import '../domain/product.dart';
import '../domain/store.dart';

/// Catalogo publico: no necesita token.
///
/// ponytail: sin cache ni interfaz abstracta. La cascada marca -> modelo -> año
/// se pide al backend en cada cambio porque son tres listas de texto que tardan
/// menos que dibujar el desplegable; poner cache cuando se note.
class CatalogRepository {
  const CatalogRepository(this._api);

  final ApiClient _api;

  /// Trae las categorias y actualiza el mapa global `categoryLabels`.
  Future<void> loadCategories() async {
    final rows = asMapList(await _api.get('/catalog/categories'));
    if (rows.isEmpty) return;
    categoryLabels
      ..clear()
      ..addEntries(
        rows.map((r) => MapEntry(r['key'] as String, r['label'] as String)),
      );
  }

  /// Admin y tiendas. Devuelve la clave (si ya existia, la misma).
  Future<String> createCategory(String label) async {
    final r = asMap(
      await _api.post('/catalog/categories', body: {'label': label}),
    );
    categoryLabels[r['key'] as String] = r['label'] as String;
    return r['key'] as String;
  }

  /// Cascada tipo -> marca -> modelo -> año. `motoType` acota los tres
  /// siguientes (una tolva no existe en la lineal).
  Future<List<String>> motoBrands({String? motoType}) async => (await _api.get(
    '/catalog/moto-brands',
    query: {'moto_type': motoType},
  ) as List).cast<String>();

  Future<List<String>> motoModels(String motoBrand, {String? motoType}) async =>
      (await _api.get(
        '/catalog/moto-models',
        query: {'moto_brand': motoBrand, 'moto_type': motoType},
      ) as List).cast<String>();

  Future<List<int>> motoYears(
    String motoBrand,
    String motoModel, {
    String? motoType,
  }) async => (await _api.get(
    '/catalog/moto-years',
    query: {
      'moto_brand': motoBrand,
      'moto_model': motoModel,
      'moto_type': motoType,
    },
  ) as List).cast<int>();

  Future<ProductPage> products({
    String? q,
    String? category,
    String? brand,
    String? partCode,
    String? motoType,
    String? motoBrand,
    String? motoModel,
    int? year,
    int? storeId,
    bool? onlyInStock,
    bool? onlyVerified,
    double? minPrice,
    double? maxPrice,
    String orderBy = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get(
      '/catalog/products',
      query: {
        'q': q,
        'category': category,
        'brand': brand,
        'part_code': partCode,
        'moto_type': motoType,
        'moto_brand': motoBrand,
        'moto_model': motoModel,
        'year': year,
        'store_id': storeId,
        'only_in_stock': onlyInStock,
        'only_verified': onlyVerified,
        'min_price': minPrice,
        'max_price': maxPrice,
        'order_by': orderBy,
        'limit': limit,
        'offset': offset,
      },
    );
    return ProductPage.fromJson(asMap(data));
  }

  /// Detalle + `offers`: la misma pieza en otras tiendas, ya ordenada por
  /// precio y luego por distancia.
  Future<Product> product(int id) async =>
      Product.fromJson(asMap(await _api.get('/catalog/products/$id')));

  /// Tiendas (para el directorio y el mapa). `withLocation` = solo con lat/lng.
  Future<List<Store>> stores({
    String? q,
    bool withLocation = false,
    bool onlyVerified = false,
  }) async => asMapList(
    await _api.get(
      '/catalog/stores',
      query: {
        'q': q,
        'with_location': withLocation ? true : null,
        'only_verified': onlyVerified ? true : null,
      },
    ),
  ).map(Store.fromJson).toList();

  Future<Store> store(int id) async =>
      Store.fromJson(asMap(await _api.get('/catalog/stores/$id')));

  // ---- Alertas de stock / precio ----
  Future<List<Map<String, dynamic>>> alerts() async =>
      asMapList(await _api.get('/alerts'));

  Future<void> createAlert({
    required String partCode,
    double? maxPrice,
    bool notifyStock = true,
  }) => _api.post(
    '/alerts',
    body: {
      'part_code': partCode,
      'max_price': maxPrice,
      'notify_stock': notifyStock,
    },
  );

  Future<void> deleteAlert(int id) => _api.delete('/alerts/$id');

  Future<List<StoreReview>> storeReviews(int id) async =>
      asMapList(await _api.get('/catalog/stores/$id/reviews'))
          .map(StoreReview.fromJson)
          .toList();
}
