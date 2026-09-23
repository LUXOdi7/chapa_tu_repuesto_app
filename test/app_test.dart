import 'package:chapa_tu_repuesto_app/core/format.dart';
import 'package:chapa_tu_repuesto_app/core/network/api_client.dart';
import 'package:chapa_tu_repuesto_app/features/auth/data/auth_repository.dart';
import 'package:chapa_tu_repuesto_app/features/auth/domain/user.dart';
import 'package:chapa_tu_repuesto_app/features/auth/presentation/session.dart';
import 'package:chapa_tu_repuesto_app/features/cart/presentation/cart_store.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/domain/compatibility.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/domain/product.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/presentation/widgets/voice_search_bar.dart';
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

  test('cerrar sesion avisa a la UI aunque falle el almacenamiento o Google', () async {
    // En web, GoogleSignIn.signOut() sin initialize se colgaba y la app no
    // volvia al login. Sin plugins (como aqui) tampoco debe reventar.
    final api = ApiClient();
    final session = Session(api, AuthRepository(api));
    var notified = false;
    session.addListener(() => notified = true);
    await session.signOut();
    expect(notified, isTrue);
    expect(session.user, isNull);
  });

  test('los null no viajan en el cuerpo (el backend tiene defaults y un null da 422)', () {
    expect(ApiClient.stripNulls({'a': 1, 'b': null, 'c': ''}), {'a': 1, 'c': ''});
    expect(ApiClient.stripNulls([1, null]), [1, null]); // solo mapas
  });

  test('los tres tipos de moto se etiquetan y viajan en el contrato', () {
    expect(motoTypeLabel('lineal'), 'Moto lineal');
    expect(motoTypeLabel('carguero'), 'Moto carguera');
    expect(motoTypeLabel('mototaxi'), 'Mototaxi');
    expect(motoTypeLabel(null), ''); // sin tipo no rompe la UI
    final c = Compatibility.fromJson({
      'moto_type': 'mototaxi', 'moto_brand': 'Bajaj', 'moto_model': 'RE 4S Torito',
      'year_from': 2012, 'year_to': 2025,
    });
    expect(c.fullLabel, 'Mototaxi · Bajaj RE 4S Torito 2012-2025');
    expect(c.toJson()['moto_type'], 'mototaxi');
    // Compatibilidad vieja sin tipo: lineal por defecto
    expect(Compatibility.fromJson({'moto_brand': 'Honda', 'moto_model': 'XR 150L'}).motoType, 'lineal');
    final moto = UserMoto.fromJson({'id': 1, 'moto_type': 'carguero', 'moto_brand': 'Wanxin', 'moto_model': 'WX 200 Carga', 'year': 2021});
    expect(moto.fullLabel, 'Moto carguera · Wanxin WX 200 Carga 2021');
  });

  test('la direccion guardada y el punto de entrega del pedido', () {
    final user = User.fromJson({
      'id': 1, 'name': 'Taller', 'email': 't@x.pe', 'role': 'buyer',
      'address': 'Av. Grau 100', 'latitude': -6.77, 'longitude': -79.84,
    });
    expect(user.hasSavedAddress, isTrue);
    expect(user.latitude, -6.77);
    expect(User.fromJson({'id': 2, 'name': 'X', 'email': 'x@x.pe', 'role': 'buyer'}).hasSavedAddress, isFalse);
    final order = Order.fromJson({...orderJson, 'delivery_lat': -6.78, 'delivery_lng': -79.85});
    expect(order.hasDeliveryPoint, isTrue);
    expect(Order.fromJson(orderJson).hasDeliveryPoint, isFalse);
  });

  test('las tarjetas muestran marca y codigo juntos', () {
    expect(Product.fromJson(productJson).brandAndCode, 'NGK  ·  BJ-CR8EIX');
    // Sin marca (pedidos viejos) no deja separadores sueltos
    expect(Product.fromJson({...productJson, 'brand': null}).brandAndCode, 'BJ-CR8EIX');
    final item = OrderItem.fromJson({
      'product_id': 1, 'product_name': 'Bujia', 'part_code': 'BJ-CR8EIX',
      'brand': 'NGK', 'unit_price': 40.0, 'quantity': 1, 'subtotal': 40.0,
    });
    expect(item.brandAndCode, 'NGK  ·  BJ-CR8EIX');
  });

  test('los fallos del microfono se explican al usuario, no se tragan', () {
    // Codigos reales de la Web Speech API / Android.
    expect(speechErrorText('not-allowed'), contains('bloqueó el micrófono'));
    expect(speechErrorText('audio-capture'), contains('micrófono conectado'));
    expect(speechErrorText('no-speech'), contains('No se escuchó nada'));
    expect(speechErrorText('not supported'), contains('Chrome o Edge'));
    expect(speechErrorText('raro-123'), contains('raro-123')); // nunca vacio
  });

  test('el chat muestra la fecha una vez por dia y la hora en la burbuja', () {
    final now = DateTime(2026, 9, 15, 10, 0);
    expect(dayLabel(DateTime(2026, 9, 15, 8), now: now), 'Hoy');
    expect(dayLabel(DateTime(2026, 9, 14, 23, 59), now: now), 'Ayer');
    expect(dayLabel(DateTime(2026, 9, 1), now: now), '01/09/2026');
    expect(timeLabel(DateTime(2026, 9, 15, 8, 5)), '08:05');
    expect(sameDay(DateTime(2026, 9, 15, 0, 1), DateTime(2026, 9, 15, 23, 59)), isTrue);
    expect(sameDay(DateTime(2026, 9, 15, 23, 59), DateTime(2026, 9, 16, 0, 0)), isFalse);
  });

  test('el pedido trae chat y reputacion del comprador', () {
    final order = Order.fromJson({
      ...orderJson,
      'buyer': {'id': 1, 'name': 'Taller', 'rating_avg': 4.5, 'rating_count': 2},
      'message_count': 3,
      'can_review_buyer': true,
    });
    expect(order.messageCount, 3);
    expect(order.canReviewBuyer, isTrue);
    expect(order.buyerRatingLabel, '4.5 ★ (2)');
    final msg = ChatMessage.fromJson({'id': 9, 'sender_id': 1, 'sender_name': 'Taller', 'body': 'hola', 'created_at': '2026-09-08T00:35:14'});
    expect(msg.body, 'hola');
    expect(UserMoto.fromJson({'id': 1, 'moto_brand': 'Bajaj', 'moto_model': 'Pulsar NS 200', 'year': 2020}).label, 'Bajaj Pulsar NS 200 2020');
  });

  test('la pagina de resultados expone lo entendido del dictado como chips', () {
    final page = ProductPage.fromJson({
      'total': 1,
      'items': [productJson],
      'parsed': {'year': 2020, 'moto': ['pulsar', '200'], 'brands': ['Brembo'], 'category': 'frenos', 'terms': ['pastilla']},
    });
    expect(page.parsedChips, ['2020', 'pulsar', '200', 'Brembo', 'Frenos', 'pastilla']);
    expect(ProductPage.fromJson({'total': 0, 'items': []}).parsedChips, isEmpty);
  });

  test('los importes se aceptan como numero o como texto', () {
    // El panel del proveedor serializaba Decimal como "28.38".
    expect(Product.fromJson({...productJson, 'price': '28.38'}).price, 28.38);
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
    // Sin `events`/`buyer`/`payment_provider` (respuesta antigua) tampoco revienta.
    expect(order.events, isEmpty);
    expect(order.storeHasGateway, isFalse);
  });

  test('el pedido con pasarela y eventos decide el flujo de pago', () {
    final order = Order.fromJson({
      ...orderJson,
      'store': {...orderJson['store'] as Map, 'payment_provider': 'mercadopago'},
      'buyer': {'id': 1, 'name': 'Taller Julio', 'phone': '999', 'email': 'j@x.pe'},
      'events': [
        {'status': 'created', 'status_label': 'Creado', 'note': '', 'created_at': '2026-09-08T00:35:14'},
      ],
    });
    // Tarjeta en tienda con Mercado Pago/Niubiz: abre el checkout externo.
    expect(order.storeHasGateway, isTrue);
    expect(order.buyerName, 'Taller Julio');
    expect(order.events.single.status, 'created');
    expect(order.events.single.at.isUtc, isFalse); // ya convertida a local
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
