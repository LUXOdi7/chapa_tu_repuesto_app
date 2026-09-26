import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../catalog/domain/product.dart';
import '../../catalog/domain/store.dart';
import '../domain/cart_item.dart';

/// Envio: S/ 10.00 por proveedor, gratis desde S/ 250 de subtotal.
/// ponytail: la regla vive en el backend, aqui se repite solo para poder
/// mostrar el total antes de pagar. El importe que se cobra es el que devuelve
/// `/orders/checkout`, no este. Si la regla cambia, cambia en los dos lados.
const kShippingPerStore = 10.0;
const kFreeShippingFrom = 250.0;

/// Un grupo del carrito = un pedido futuro. El backend parte el checkout en una
/// orden por tienda, asi que el comprador ve desde el carrito en cuantos
/// pedidos se va a dividir.
class CartGroup {
  const CartGroup({required this.store, required this.items});

  final Store store;
  final List<CartItem> items;

  double get subtotal => items.fold(0.0, (t, i) => t + i.subtotal);
  double get shipping => subtotal >= kFreeShippingFrom ? 0 : kShippingPerStore;
  double get total => subtotal + shipping;
}

/// Carrito. Vive SOLO en la app: el backend no tiene tabla de carrito, recibe
/// el carrito completo al pagar.
///
/// Se persiste en el dispositivo para que no se pierda al cerrar la app.
/// ponytail: se guarda en `flutter_secure_storage`, que ya es dependencia por
/// el JWT, en vez de agregar `shared_preferences` solo para esto.
class CartStore extends ChangeNotifier {
  static const _key = 'ctr_cart';

  final Map<int, CartItem> _items = {};
  final _storage = const FlutterSecureStorage();

  List<CartItem> get items => _items.values.toList();

  bool get isEmpty => _items.isEmpty;

  /// Unidades totales (badge del icono de carrito).
  int get unitCount => _items.values.fold(0, (n, i) => n + i.quantity);

  double get subtotal => _items.values.fold(0.0, (t, i) => t + i.subtotal);

  double get shipping => groups.fold(0.0, (t, g) => t + g.shipping);

  double get total => subtotal + shipping;

  int quantityOf(int productId) => _items[productId]?.quantity ?? 0;

  List<CartGroup> get groups {
    final byStore = <int, List<CartItem>>{};
    final stores = <int, Store>{};
    for (final item in _items.values) {
      final store = item.product.store;
      if (store == null) continue;
      stores[store.id] = store;
      byStore.putIfAbsent(store.id, () => []).add(item);
    }
    return [
      for (final entry in byStore.entries)
        CartGroup(store: stores[entry.key]!, items: entry.value),
    ];
  }

  /// Suma unidades respetando el stock que reporto el backend. El tope real lo
  /// vuelve a validar el checkout (otro comprador pudo llevarse el ultimo).
  void add(Product product, {int quantity = 1}) {
    if (!product.inStock) return;
    final current = _items[product.id]?.quantity ?? 0;
    _items[product.id] = CartItem(
      product: product,
      quantity: (current + quantity).clamp(1, product.stock),
    );
    _changed();
  }

  void setQuantity(int productId, int quantity) {
    final item = _items[productId];
    if (item == null) return;
    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      _items[productId] = item.copyWith(
        quantity: quantity.clamp(1, item.product.stock),
      );
    }
    _changed();
  }

  void remove(int productId) {
    _items.remove(productId);
    _changed();
  }

  void clear() {
    _items.clear();
    _changed();
  }

  Future<void> restore() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return;
    try {
      for (final entry in jsonDecode(raw) as List) {
        final item = CartItem.fromJson((entry as Map).cast<String, dynamic>());
        _items[item.product.id] = item;
      }
      notifyListeners();
    } catch (_) {
      // Carrito guardado por una version anterior del modelo: se descarta.
      await _storage.delete(key: _key);
    }
  }

  void _changed() {
    notifyListeners();
    // El guardado es best-effort: si el almacenamiento falla (o no existe, como
    // en los tests) el carrito en memoria tiene que seguir funcionando.
    unawaited(
      _storage
          .write(
            key: _key,
            value: jsonEncode([for (final i in _items.values) i.toJson()]),
          )
          .catchError((Object _) {}),
    );
  }
}
