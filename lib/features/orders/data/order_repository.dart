import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
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
    final data = await _api.post(
      '/orders/checkout',
      body: {
        'items': [
          for (final item in items)
            {'product_id': item.product.id, 'quantity': item.quantity},
        ],
        'delivery_address': deliveryAddress,
        'payment_method': paymentMethod.key,
        'notes': notes,
      },
    );
    return asMapList(data).map(Order.fromJson).toList();
  }

  /// Si el usuario es proveedor, el backend devuelve los pedidos de SU tienda;
  /// con `asBuyer` (modo comprador) devuelve sus compras.
  Future<List<Order>> list({String? statusFilter, bool asBuyer = false}) async {
    final data = await _api.get(
      '/orders',
      query: {
        'status_filter': statusFilter,
        'as_role': asBuyer ? 'buyer' : null,
      },
    );
    return asMapList(data).map(Order.fromJson).toList();
  }

  Future<Order> byId(int id) async =>
      Order.fromJson(asMap(await _api.get('/orders/$id')));

  /// Inicia el cobro con tarjeta por la pasarela de la tienda.
  /// Devuelve `checkout_url` para abrir en el navegador (Mercado Pago / Niubiz)
  /// o null si la tienda no tiene pasarela: el backend ya aprobo el pago.
  Future<PaymentStart> startPayment(int id) async {
    final data = asMap(await _api.post('/payments/$id/start'));
    return PaymentStart(
      provider: data['provider'] as String,
      checkoutUrl: data['checkout_url'] as String?,
      order: Order.fromJson(asMap(data['order'])),
    );
  }

  /// Pago manual (Yape / transferencia): sin numero de operacion el backend
  /// genera uno "SIM...".
  Future<Order> pay(
    int id, {
    required PaymentMethod method,
    String? operationNumber,
  }) async {
    final data = await _api.post(
      '/orders/$id/payment',
      body: {'payment_method': method.key, 'operation_number': operationNumber},
    );
    return Order.fromJson(asMap(data));
  }

  Future<Order> setStatus(int id, String status) async {
    final data = await _api.patch(
      '/orders/$id/status',
      body: {'status': status},
    );
    return Order.fromJson(asMap(data));
  }

  /// Constancia en JSON (los importes vienen como texto ya formateado).
  /// ponytail: la misma constancia existe en `/orders/{id}/receipt.html` lista
  /// para imprimir; se dibuja desde el JSON para no arrastrar `webview_flutter`
  /// solo por eso. Cambiar cuando haga falta el PDF/impresion.
  Future<Map<String, dynamic>> receipt(int id) async =>
      asMap(await _api.get('/orders/$id/receipt'));

  /// URL absoluta al PDF con un token firmado de 10 min: se abre con
  /// `url_launcher` en Android y web sin mandar cabeceras.
  Future<String> receiptPdfUrl(int id) async => ApiConfig.imageUrl(
    asMap(await _api.get('/orders/$id/receipt-link'))['path'] as String,
  )!;

  /// Solo se puede calificar un pedido entregado; al hacerlo queda cerrado.
  Future<void> review(int id, {required int rating, String? comment}) => _api
      .post('/orders/$id/review', body: {'rating': rating, 'comment': comment});

  /// `afterId`: solo lo nuevo (el chat refresca cada pocos segundos).
  Future<List<ChatMessage>> messages(int orderId, {int afterId = 0}) async =>
      asMapList(
        await _api.get(
          '/orders/$orderId/messages',
          query: {'after_id': afterId > 0 ? afterId : null},
        ),
      ).map(ChatMessage.fromJson).toList();

  Future<ChatMessage> sendMessage(int orderId, String body) async =>
      ChatMessage.fromJson(
        asMap(
          await _api.post('/orders/$orderId/messages', body: {'body': body}),
        ),
      );

  /// La tienda califica al comprador (pedido entregado o cerrado).
  Future<Order> reviewBuyer(
    int orderId, {
    required int rating,
    String? comment,
  }) async => Order.fromJson(
    asMap(
      await _api.post(
        '/orders/$orderId/buyer-review',
        body: {'rating': rating, 'comment': comment},
      ),
    ),
  );
}

class PaymentStart {
  const PaymentStart({
    required this.provider,
    required this.order,
    this.checkoutUrl,
  });

  final String provider;
  final String? checkoutUrl;
  final Order order;
}
