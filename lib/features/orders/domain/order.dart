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
    this.imageUrl,
  });

  final int productId;
  final String productName;
  final String? partCode;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'] as int,
        productName: json['product_name'] as String? ?? '',
        partCode: json['part_code'] as String?,
        imageUrl: json['image_url'] as String?,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        quantity: json['quantity'] as int? ?? 1,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
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
    this.paymentOpNumber,
    this.paidAt,
    this.deliveryAddress,
    this.notes,
    this.updatedAt,
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
  final DateTime? paidAt;
  final String? deliveryAddress;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Store store;
  final List<OrderItem> items;

  bool get isCancelled => status == 'cancelled';
  bool get canPay => status == 'created';

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? 'created',
        statusLabel: json['status_label'] as String? ?? '',
        nextStatus: (json['next_status'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        shippingCost: (json['shipping_cost'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        paymentMethod: PaymentMethod.parse(json['payment_method'] as String?),
        paymentOpNumber: json['payment_op_number'] as String?,
        paidAt: parseServerDateOrNull(json['paid_at'] as String?),
        deliveryAddress: json['delivery_address'] as String?,
        notes: json['notes'] as String?,
        createdAt: parseServerDate(json['created_at'] as String),
        updatedAt: parseServerDateOrNull(json['updated_at'] as String?),
        store: Store.fromJson((json['store'] as Map).cast<String, dynamic>()),
        items: (json['items'] as List?)
                ?.map((e) => OrderItem.fromJson((e as Map).cast<String, dynamic>()))
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
