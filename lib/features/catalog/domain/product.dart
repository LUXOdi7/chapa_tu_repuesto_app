import 'compatibility.dart';
import 'store.dart';

/// Repuesto publicado por una tienda.
///
/// El listado (`/catalog/products`) trae los campos hasta `store`; el detalle
/// (`/catalog/products/{id}`) agrega `description`, `compatibilities` y
/// `offers` (la MISMA pieza en otras tiendas, ya ordenada por precio y luego
/// por distancia: es el comparador de ofertas).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.partCode,
    required this.price,
    required this.stock,
    required this.inStock,
    this.brand,
    this.imageUrl,
    this.warrantyMonths,
    this.store,
    this.description,
    this.compatibilities = const [],
    this.offers = const [],
    this.isActive = true,
  });

  final int id;
  final String name;
  final String category;

  /// Codigo del fabricante: es la llave que agrupa la misma pieza entre
  /// distintas tiendas.
  final String partCode;

  /// Marca del repuesto (NGK, Brembo...), no la marca de la moto.
  final String? brand;

  /// Ruta relativa que devuelve el backend; usa `ApiConfig.imageUrl` para
  /// convertirla en URL absoluta. Puede ser null.
  final String? imageUrl;
  final double price;
  final int stock;
  final bool inStock;
  final int? warrantyMonths;
  final Store? store;
  final String? description;
  final List<Compatibility> compatibilities;
  final List<Product> offers;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        partCode: json['part_code'] as String? ?? '',
        brand: json['brand'] as String?,
        imageUrl: json['image_url'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        stock: json['stock'] as int? ?? 0,
        // El backend ya calcula `in_stock`; el fallback cubre las respuestas
        // del panel del proveedor, que no lo incluyen.
        inStock: json['in_stock'] as bool? ?? ((json['stock'] as int? ?? 0) > 0),
        warrantyMonths: json['warranty_months'] as int?,
        store: json['store'] == null
            ? null
            : Store.fromJson((json['store'] as Map).cast<String, dynamic>()),
        description: json['description'] as String?,
        compatibilities: _list(json['compatibilities'])
            .map(Compatibility.fromJson)
            .toList(),
        offers: _list(json['offers']).map(Product.fromJson).toList(),
        isActive: json['is_active'] as bool? ?? true,
      );

  /// Solo lo que el carrito necesita conservar entre sesiones.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'part_code': partCode,
        'brand': brand,
        'image_url': imageUrl,
        'price': price,
        'stock': stock,
        'in_stock': inStock,
        'warranty_months': warrantyMonths,
        'store': store?.toJson(),
      };

  static List<Map<String, dynamic>> _list(dynamic raw) => raw is List
      ? raw.map((e) => (e as Map).cast<String, dynamic>()).toList()
      : const [];
}

/// Pagina de resultados de `/catalog/products`.
class ProductPage {
  const ProductPage({
    required this.total,
    required this.items,
    this.limit = 20,
    this.offset = 0,
  });

  final int total;
  final List<Product> items;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory ProductPage.fromJson(Map<String, dynamic> json) => ProductPage(
        total: json['total'] as int? ?? 0,
        limit: json['limit'] as int? ?? 20,
        offset: json['offset'] as int? ?? 0,
        items: Product._list(json['items']).map(Product.fromJson).toList(),
      );
}
