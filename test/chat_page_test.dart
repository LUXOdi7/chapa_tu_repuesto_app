import 'dart:convert';

import 'package:chapa_tu_repuesto_app/core/app_scope.dart';
import 'package:chapa_tu_repuesto_app/core/app_theme.dart';
import 'package:chapa_tu_repuesto_app/core/network/api_client.dart';
import 'package:chapa_tu_repuesto_app/features/admin/data/admin_repository.dart';
import 'package:chapa_tu_repuesto_app/features/auth/data/auth_repository.dart';
import 'package:chapa_tu_repuesto_app/features/auth/presentation/session.dart';
import 'package:chapa_tu_repuesto_app/features/cart/presentation/cart_store.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/data/catalog_repository.dart';
import 'package:chapa_tu_repuesto_app/features/orders/data/order_repository.dart';
import 'package:chapa_tu_repuesto_app/features/orders/domain/order.dart';
import 'package:chapa_tu_repuesto_app/features/orders/presentation/chat_page.dart';
import 'package:chapa_tu_repuesto_app/features/supplier/data/supplier_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El chat del pedido refresca cada 4 s con `after_id`. Si un refresco SALE
/// antes de enviar y RESPONDE despues, su respuesta ya trae el mensaje recien
/// enviado y la burbuja aparecia dos veces (solo al que escribe: la otra parte
/// recibe el mensaje una sola vez, por el refresco).
///
/// Este backend falso puede retener el GET para reproducir esa carrera exacta.
class _FakeBackend implements HttpClientAdapter {
  final mensajes = <Map<String, Object>>[];

  /// Cuando es `true`, el GET contesta como si su `after_id` fuera el de
  /// antes del envio: eso es exactamente lo que devuelve el refresco que ya
  /// estaba en vuelo cuando el comprador mando el mensaje.
  bool respondeConAfterIdViejo = false;

  int _siguienteId = 1;

  ResponseBody _json(Object data, [int code = 200]) => ResponseBody.fromString(
    jsonEncode(data),
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async {
    if (options.method == 'POST') {
      final msg = <String, Object>{
        'id': _siguienteId++,
        'sender_id': 7,
        'sender_name': 'Taller Julio',
        'body': (options.data as Map)['body'] as String,
        'created_at': '2026-09-25T20:05:00',
      };
      mensajes.add(msg);
      return _json(msg, 201);
    }
    final desde = respondeConAfterIdViejo
        ? 0
        : int.tryParse('${options.queryParameters['after_id'] ?? 0}') ?? 0;
    return _json(mensajes.where((m) => (m['id'] as int) > desde).toList());
  }

  @override
  void close({bool force = false}) {}
}

Order _pedido() => Order.fromJson({
  'id': 1,
  'code': 'CTR-000001',
  'status': 'payment_verified',
  'status_label': 'Pago verificado',
  'next_status': <String>[],
  'subtotal': 100.0,
  'shipping_cost': 10.0,
  'total': 110.0,
  'created_at': '2026-09-25T20:00:00',
  'updated_at': '2026-09-25T20:00:00',
  'store': {'id': 1, 'business_name': 'Repuestos Demo'},
  'buyer': {'id': 7, 'name': 'Taller Julio', 'phone': null, 'email': 'j@x.pe'},
  'items': <dynamic>[],
  'events': <dynamic>[],
});

Widget _app(ApiClient api) {
  final auth = AuthRepository(api);
  return AppScope(
    api: api,
    session: Session(api, auth),
    auth: auth,
    catalog: CatalogRepository(api),
    orders: OrderRepository(api),
    suppliers: SupplierRepository(api),
    admin: AdminRepository(api),
    cart: CartStore(),
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: ChatPage(order: _pedido()),
    ),
  );
}

/// Deja que el chat termine su primera carga (queda vacio).
Future<void> _abrir(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(_app(api));
  await tester.pump();
  await tester.pump();
}

/// Desmonta el chat (para el Timer de 4 s) y deja que dio suelte sus timers
/// internos de timeout; si no, el test termina con "pending timers".
Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('el mensaje propio no se duplica si el refresco en vuelo lo '
      'devuelve', (tester) async {
    final backend = _FakeBackend();
    final api = ApiClient(dio: Dio()..httpClientAdapter = backend);
    await _abrir(tester, api);

    await tester.enterText(find.byType(TextField), 'hola, ¿ya lo despacharon?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();
    expect(find.text('hola, ¿ya lo despacharon?'), findsOneWidget);

    // Llega la respuesta del refresco que salio antes del envio: trae de
    // vuelta el mensaje que ya esta en pantalla.
    backend.respondeConAfterIdViejo = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('hola, ¿ya lo despacharon?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _cerrar(tester);
  });

  testWidgets('los mensajes de la tienda llegan y no se repiten', (
    tester,
  ) async {
    final backend = _FakeBackend();
    final api = ApiClient(dio: Dio()..httpClientAdapter = backend);
    await _abrir(tester, api);

    backend.mensajes.add({
      'id': 99,
      'sender_id': 3,
      'sender_name': 'Repuestos Demo',
      'body': 'Sale mañana temprano',
      'created_at': '2026-09-25T20:10:00',
    });
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Sale mañana temprano'), findsOneWidget);

    // Dos refrescos mas: sigue habiendo una sola burbuja.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('Sale mañana temprano'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _cerrar(tester);
  });
}
