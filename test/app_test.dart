import 'package:chapa_tu_repuesto_app/core/format.dart';
import 'package:chapa_tu_repuesto_app/features/cart/presentation/cart_store.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/domain/product.dart';
import 'package:chapa_tu_repuesto_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que rompe la app en silencio ahora que los datos vienen del backend:
/// el parseo del contrato, las fechas UTC, el formato de moneda y la
/// agrupacion del carrito por tienda.
///
/// No hay tests de red: probar `dio` contra un mock no prueba el backend, y el
/// backend ya se prueba solo. Estos corren sin servidor.
void main() {
  // Respuestas reales del contrato (ANDROID.md), recortadas.
  final productJson = <String, dynamic>{
    'id': 51,
    'name': 'Bujia iridium',
    'category': 'electrico',
    'part_code': 'BJ-CR8EIX',
    'brand': 'NGK',
    'image_url': null,
    'price': 46.05,
    'stock': 0,
    'in_stock': false,
    'warranty_months': 6,
    'store': {
      'id': 4,
      'business_name': 'Autopartes Motupe SAC',
      'district': 'Motupe',
      'distance_km': 12.5,
      'rating_avg': 4.3,
      'rating_count': 40,
      'verified': true,
    },
  };

  final orderJson = <String, dynamic>{
    'id': 7,
    'code': 'CTR-000007',
    'status': 'created',
    'status_label': 'Creado (pago pendiente)',
    'next_status': ['payment_verified', 'cancelled'],
    'subtotal': 21.7,
    'shipping_cost': 10.0,
    'total': 31.7,
    'payment_method': 'yape',
    'payment_op_number': null,
    'paid_at': null,
    'delivery_address': 'Av. Los Mecanicos 320',
    'notes': 'antes de las 6pm',
    'created_at': '2026-09-08T00:35:14.484325',
    'updated_at': '2026-09-08T00:35:14.484325',
    'store': {
      'id': 5,
      'business_name': 'Todo Moto JLO',
      'phone': '979556677',
      'address': 'Av. Chinchaysuyo 1580',
    },
    'items': [
      {
        'product_id': 69,
        'product_name': 'Filtro de aceite',
        'part_code': 'FA-HF112',
        'image_url': null,
        'unit_price': 21.7,
        'quantity': 1,
        'subtotal': 21.7,
      }
    ],
  };

  test('el producto del catálogo se parsea completo', () {
    final product = Product.fromJson(productJson);

    expect(product.id, 51);
    expect(product.inStock, isFalse);
    expect(product.price, 46.05);
    expect(product.store?.businessName, 'Autopartes Motupe SAC');
    expect(product.store?.distanceKm, 12.5);
    // Campos ausentes en el listado: no pueden reventar.
    expect(product.compatibilities, isEmpty);
    expect(product.offers, isEmpty);
    expect(product.description, isNull);
  });

  test('el producto sobrevive al ida y vuelta del carrito persistido', () {
    final restored = Product.fromJson(Product.fromJson(productJson).toJson());
    expect(restored.id, 51);
    expect(restored.price, 46.05);
    expect(restored.store?.id, 4);
  });

  test('el pedido se parsea y expone next_status', () {
    final order = Order.fromJson(orderJson);

    expect(order.code, 'CTR-000007');
    expect(order.statusLabel, 'Creado (pago pendiente)');
    expect(order.nextStatus, ['payment_verified', 'cancelled']);
    expect(order.canPay, isTrue);
    expect(order.total, 31.7);
    expect(order.items.single.productName, 'Filtro de aceite');
    expect(order.store.businessName, 'Todo Moto JLO');
    // Ni `paid_at` ni `payment_op_number` vienen: siguen siendo null.
    expect(order.paidAt, isNull);
  });

  test('las fechas del backend son UTC aunque no traigan zona', () {
    // Si se parsearan como hora local, el pedido aparecería con horas de
    // diferencia segun donde este el celular.
    final parsed = parseServerDate('2026-09-08T00:35:14.484325');
    expect(parsed.toUtc().hour, 0);
    expect(parsed.toUtc().minute, 35);
    // Con zona explicita no se debe volver a marcar.
    expect(parseServerDate('2026-09-08T00:35:14Z').toUtc().hour, 0);
  });

  test('los importes se muestran con separador de miles', () {
    expect(soles(1234.5), 'S/ 1,234.50');
    expect(soles(46.05), 'S/ 46.05');
    expect(soles(0), 'S/ 0.00');
    expect(soles(1234567.891), 'S/ 1,234,567.89');
  });

  test('las categorías crudas del backend se traducen', () {
    expect(categoryLabel('electrico'), 'Eléctrico');
    expect(categoryLabel('transmision'), 'Transmisión');
    // Una categoria nueva no puede dejar un hueco en la UI.
    expect(categoryLabel('suspension'), 'Suspension');
  });

  test('el carrito agrupa por tienda, respeta el stock y cobra un envío por '
      'proveedor', () {
    final bujia =
        Product.fromJson({...productJson, 'stock': 10, 'in_stock': true});
    final agotado = Product.fromJson({...productJson, 'id': 52});
    final caroOtraTienda = Product.fromJson({
      ...productJson,
      'id': 99,
      'price': 300.0,
      'stock': 5,
      'in_stock': true,
      'store': {'id': 9, 'business_name': 'Todo Moto JLO'},
    });

    final cart = CartStore();
    cart.add(bujia, quantity: 2);
    cart.add(caroOtraTienda);
    cart.add(agotado); // sin stock: no debe entrar

    expect(cart.unitCount, 3);
    expect(cart.groups.length, 2, reason: 'dos tiendas = dos pedidos');
    expect(cart.subtotal, closeTo(46.05 * 2 + 300, 0.001));
    // S/ 10 de envio en la tienda que no llega a S/ 250; gratis en la otra.
    expect(cart.shipping, closeTo(kShippingPerStore, 0.001));

    // Tope duro en el stock que reporto el backend.
    cart.add(bujia, quantity: 99);
    expect(cart.quantityOf(bujia.id), 10);

    cart.remove(caroOtraTienda.id);
    expect(cart.groups.length, 1);
  });
}
