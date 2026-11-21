import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../cart/domain/cart_item.dart';
import '../domain/order.dart';
import '../domain/payment_method.dart';

class OrderRepository {
  const OrderRepository(this._api);

  final ApiClient _api;

  /// DEVUELVE UNA LISTA: el backend parte el carrito en una orden por tienda.
  Future<List<Order>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    required PaymentMethod paymentMethod,
    bool isPickup = false,
    String? notes,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final data = await _api.post(
      '/orders/checkout',
      body: {
        'items': [
          for (final item in items)
            {'product_id': item.product.id, 'quantity': item.quantity},
        ],
        'is_pickup': isPickup,
        'delivery_address': deliveryAddress,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
        'payment_method': paymentMethod.key,
        'notes': notes,
      },
    );
    return asMapList(data).map(Order.fromJson).toList();
  }

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

  /// Datos del QR de Yape (telefono + imagen QR del admin).
  Future<YapeInfo> yapeInfo() async {
    final data = asMap(await _api.get('/payments/yape-info'));
    return YapeInfo(
      phone: data['phone'] as String? ?? '',
      qrImage: data['qr_image'] as String?,
    );
  }

  /// Pago manual (Yape): el comprador informa que ya pago.
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

  Future<Map<String, dynamic>> receipt(int id) async =>
      asMap(await _api.get('/orders/$id/receipt'));

  Future<String> receiptPdfUrl(int id) async => ApiConfig.imageUrl(
    asMap(await _api.get('/orders/$id/receipt-link'))['path'] as String,
  )!;

  Future<void> review(int id, {required int rating, String? comment}) => _api
      .post('/orders/$id/review', body: {'rating': rating, 'comment': comment});

  /// `channel`: "supplier" o "admin". `afterId`: solo lo nuevo.
  Future<List<ChatMessage>> messages(
    int orderId, {
    int afterId = 0,
    String channel = 'supplier',
  }) async =>
      asMapList(
        await _api.get(
          '/orders/$orderId/messages',
          query: {
            'after_id': afterId > 0 ? afterId : null,
            'channel': channel,
          },
        ),
      ).map(ChatMessage.fromJson).toList();

  Future<ChatMessage> sendMessage(
    int orderId,
    String body, {
    String? imageUrl,
    String channel = 'supplier',
  }) async =>
      ChatMessage.fromJson(
        asMap(
          await _api.post(
            '/orders/$orderId/messages',
            body: {'body': body, 'image_url': imageUrl, 'channel': channel},
          ),
        ),
      );

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

class YapeInfo {
  const YapeInfo({required this.phone, this.qrImage});

  final String phone;
  final String? qrImage;
}
