import '../../../core/network/api_client.dart';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../catalog/domain/store.dart';
import 'payment_method.dart';

/// Una linea del pedido. Es una foto del producto en el momento de la compra:
/// el precio queda congelado aunque la tienda lo cambie despues.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.partCode,
    this.brand,
    this.imageUrl,
  });

  final int productId;
  final String productName;
  final String? partCode;

  /// Marca del repuesto congelada al comprar (NGK, Brembo...).
  final String? brand;
  final String? imageUrl;

  /// "NGK · BJ-CR8EIX" (omite lo que falte).
  String get brandAndCode =>
      [brand, partCode].where((t) => t != null && t.isNotEmpty).join('  ·  ');
  final double unitPrice;
  final int quantity;
  final double subtotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: json['product_id'] as int,
    productName: json['product_name'] as String? ?? '',
    partCode: json['part_code'] as String?,
    brand: json['brand'] as String?,
    imageUrl: json['image_url'] as String?,
    unitPrice: asDouble(json['unit_price']) ?? 0,
    quantity: json['quantity'] as int? ?? 1,
    subtotal: asDouble(json['subtotal']) ?? 0,
  );
}

/// Un paso del historial del pedido: quien lo movio y cuando.
class OrderEvent {
  const OrderEvent({
    required this.status,
    required this.statusLabel,
    required this.note,
    required this.at,
  });

  final String status;
  final String statusLabel;
  final String note;
  final DateTime at;

  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
    status: json['status'] as String? ?? '',
    statusLabel: json['status_label'] as String? ?? '',
    note: json['note'] as String? ?? '',
    at: parseServerDate(json['created_at'] as String),
  );
}

/// Un pedido pertenece SIEMPRE a una sola tienda: el backend parte el carrito
/// en una orden por proveedor al hacer checkout.
class Order {
  const Order({
    required this.id,
    required this.code,
    required this.status,
    required this.statusLabel,
    required this.nextStatus,
    required this.subtotal,
    required this.shippingCost,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    required this.store,
    this.items = const [],
    this.events = const [],
    this.paymentOpNumber,
    this.paymentProvider,
    this.paidAt,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.notes,
    this.updatedAt,
    this.buyerName,
    this.buyerPhone,
    this.buyerRatingAvg = 0,
    this.buyerRatingCount = 0,
    this.messageCount = 0,
    this.canReviewBuyer = false,
  });

  final int id;
  final String code;

  /// Clave cruda del estado (`created`, `payment_verified`...). Nunca se
  /// muestra: para eso esta [statusLabel], que ya viene traducido.
  final String status;
  final String statusLabel;

  /// Estados a los que ESTE usuario puede mover el pedido ahora mismo. Los
  /// botones de accion salen de aqui; la maquina de estados vive en el backend.
  final List<String> nextStatus;

  final double subtotal;
  final double shippingCost;
  final double total;
  final PaymentMethod paymentMethod;
  final String? paymentOpNumber;
  final String? paymentProvider;
  final DateTime? paidAt;
  final String? buyerName;
  final String? buyerPhone;
  final double buyerRatingAvg;
  final int buyerRatingCount;
  final int messageCount;

  /// Solo la tienda, con el pedido entregado/cerrado y sin haber calificado.
  final bool canReviewBuyer;

  String get buyerRatingLabel => buyerRatingCount == 0
      ? 'Comprador sin calificaciones'
      : '${buyerRatingAvg.toStringAsFixed(1)} ★ ($buyerRatingCount)';
  final String? deliveryAddress;

  /// Punto exacto de entrega si el comprador lo marcó en el mapa.
  final double? deliveryLat;
  final double? deliveryLng;

  bool get hasDeliveryPoint => deliveryLat != null && deliveryLng != null;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Store store;
  final List<OrderItem> items;
  final List<OrderEvent> events;

  bool get isCancelled => status == 'cancelled';
  bool get canPay => status == 'created';
  bool get isPaid => paidAt != null;

  /// La tienda cobra con tarjeta por pasarela (Mercado Pago / Niubiz): el pago
  /// pasa por `/payments/{id}/start` y abre el checkout externo.
  bool get storeHasGateway =>
      store.paymentProvider != null && store.paymentProvider != 'simulado';

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    status: json['status'] as String? ?? 'created',
    statusLabel: json['status_label'] as String? ?? '',
    nextStatus:
        (json['next_status'] as List?)?.map((e) => e as String).toList() ??
        const [],
    subtotal: asDouble(json['subtotal']) ?? 0,
    shippingCost: asDouble(json['shipping_cost']) ?? 0,
    total: asDouble(json['total']) ?? 0,
    paymentMethod: PaymentMethod.parse(json['payment_method'] as String?),
    paymentOpNumber: json['payment_op_number'] as String?,
    paymentProvider: json['payment_provider'] as String?,
    paidAt: parseServerDateOrNull(json['paid_at'] as String?),
    buyerName: (json['buyer'] as Map?)?['name'] as String?,
    buyerPhone: (json['buyer'] as Map?)?['phone'] as String?,
    buyerRatingAvg: asDouble((json['buyer'] as Map?)?['rating_avg']) ?? 0,
    buyerRatingCount: (json['buyer'] as Map?)?['rating_count'] as int? ?? 0,
    messageCount: json['message_count'] as int? ?? 0,
    canReviewBuyer: json['can_review_buyer'] as bool? ?? false,
    deliveryAddress: json['delivery_address'] as String?,
    deliveryLat: asDouble(json['delivery_lat']),
    deliveryLng: asDouble(json['delivery_lng']),
    notes: json['notes'] as String?,
    createdAt: parseServerDate(json['created_at'] as String),
    updatedAt: parseServerDateOrNull(json['updated_at'] as String?),
    store: Store.fromJson((json['store'] as Map).cast<String, dynamic>()),
    items:
        (json['items'] as List?)
            ?.map((e) => OrderItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList() ??
        const [],
    events:
        (json['events'] as List?)
            ?.map(
              (e) => OrderEvent.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        const [],
  );
}

/// Linea de tiempo del pedido. Es SOLO presentacion: el orden en que se dibujan
/// los pasos. Que transiciones estan permitidas lo decide `next_status`.
const orderTimeline = <String>[
  'created',
  'payment_verified',
  'preparing',
  'shipped',
  'delivered',
  'closed',
];

/// Etiqueta de un estado al que todavia no se llego (los alcanzados usan el
/// `status_label` que manda el backend).
String orderStatusLabel(String status) => switch (status) {
  'created' => 'Creado (pago pendiente)',
  'payment_verified' => 'Pago verificado',
  'preparing' => 'En preparación',
  'shipped' => 'Despachado',
  'delivered' => 'Entregado',
  'closed' => 'Cerrado',
  'cancelled' => 'Cancelado',
  _ => status,
};

/// Texto del boton que dispara la transicion, desde el punto de vista de quien
/// puede hacerla.
String orderActionLabel(String status) => switch (status) {
  'payment_verified' => 'Confirmar pago',
  'preparing' => 'Marcar en preparación',
  'shipped' => 'Marcar despachado',
  'delivered' => 'Confirmar recepción',
  'closed' => 'Calificar y cerrar',
  'cancelled' => 'Cancelar pedido',
  _ => orderStatusLabel(status),
};

IconData orderStatusIcon(String status) => switch (status) {
  'created' => Icons.hourglass_empty,
  'payment_verified' => Icons.verified,
  'preparing' => Icons.inventory_2,
  'shipped' => Icons.local_shipping,
  'delivered' => Icons.check_circle,
  'closed' => Icons.task_alt,
  'cancelled' => Icons.cancel,
  _ => Icons.help_outline,
};

Color orderStatusColor(String status) => switch (status) {
  'created' => Colors.orange,
  'payment_verified' => Colors.blue,
  'preparing' => Colors.indigo,
  'shipped' => Colors.purple,
  'delivered' => Colors.green,
  'closed' => Colors.teal,
  'cancelled' => Colors.red,
  _ => Colors.grey,
};

/// Mensaje del chat comprador <-> tienda dentro del pedido.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.at,
  });

  final int id;
  final int senderId;
  final String senderName;
  final String body;
  final DateTime at;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    senderId: json['sender_id'] as int,
    senderName: json['sender_name'] as String? ?? '',
    body: json['body'] as String? ?? '',
    at: parseServerDate(json['created_at'] as String),
  );
}
