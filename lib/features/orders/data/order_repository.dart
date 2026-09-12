import '../../../core/network/api_client.dart';
import '../../cart/domain/cart_item.dart';
import '../domain/order.dart';
import '../domain/payment_method.dart';

class OrderRepository {
  const OrderRepository(this._api);

  final ApiClient _api;

  /// DEVUELVE UNA LISTA: el backend parte el carrito en una orden por tienda.
  /// Un carrito con productos de 3 proveedores genera 3 pedidos, cada uno con
  /// su codigo y su envio.
  Future<List<Order>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    required PaymentMethod paymentMethod,
    String? notes,
  }) async {
    final data = await _api.post('/orders/checkout', body: {
      'items': [
        for (final item in items)
          {'product_id': item.product.id, 'quantity': item.quantity},
      ],
      'delivery_address': deliveryAddress,
      'payment_method': paymentMethod.key,
      'notes': notes,
    });
    return asMapList(data).map(Order.fromJson).toList();
  }

  /// Si el usuario es proveedor, el backend devuelve los pedidos de SU tienda.
  Future<List<Order>> list({String? statusFilter}) async {
    final data =
        await _api.get('/orders', query: {'status_filter': statusFilter});
    return asMapList(data).map(Order.fromJson).toList();
  }

  Future<Order> byId(int id) async =>
      Order.fromJson(asMap(await _api.get('/orders/$id')));

  /// Pago simulado: sin numero de operacion el backend genera uno "SIM...".
  Future<Order> pay(
    int id, {
    required PaymentMethod method,
    String? operationNumber,
  }) async {
    final data = await _api.post('/orders/$id/payment', body: {
      'payment_method': method.key,
      'operation_number': operationNumber,
    });
    return Order.fromJson(asMap(data));
  }

  Future<Order> setStatus(int id, String status) async {
    final data = await _api.patch('/orders/$id/status', body: {'status': status});
    return Order.fromJson(asMap(data));
  }

  /// Constancia en JSON (los importes vienen como texto ya formateado).
  /// ponytail: la misma constancia existe en `/orders/{id}/receipt.html` lista
  /// para imprimir; se dibuja desde el JSON para no arrastrar `webview_flutter`
  /// solo por eso. Cambiar cuando haga falta el PDF/impresion.
  Future<Map<String, dynamic>> receipt(int id) async =>
      asMap(await _api.get('/orders/$id/receipt'));

  /// Solo se puede calificar un pedido entregado; al hacerlo queda cerrado.
  Future<void> review(int id, {required int rating, String? comment}) =>
      _api.post('/orders/$id/review', body: {
        'rating': rating,
        'comment': comment,
      });
}
