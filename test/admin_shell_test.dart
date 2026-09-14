import 'dart:convert';

import 'package:chapa_tu_repuesto_app/core/app_scope.dart';
import 'package:chapa_tu_repuesto_app/core/app_theme.dart';
import 'package:chapa_tu_repuesto_app/core/network/api_client.dart';
import 'package:chapa_tu_repuesto_app/features/admin/data/admin_repository.dart';
import 'package:chapa_tu_repuesto_app/features/admin/presentation/admin_shell.dart';
import 'package:chapa_tu_repuesto_app/features/auth/data/auth_repository.dart';
import 'package:chapa_tu_repuesto_app/features/auth/presentation/session.dart';
import 'package:chapa_tu_repuesto_app/features/cart/presentation/cart_store.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/data/catalog_repository.dart';
import 'package:chapa_tu_repuesto_app/features/orders/data/order_repository.dart';
import 'package:chapa_tu_repuesto_app/features/supplier/data/supplier_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuestas reales de `/admin/*` (recortadas) servidas sin red: el panel
/// admin monta sus 5 pestañas de golpe y esto es lo que revienta primero si
/// el contrato cambia.
class _FakeAdapter implements HttpClientAdapter {
  static const _routes = <String, Object>{
    '/admin/stats': {
      'users': {'buyer': 3, 'supplier': 5, 'admin': 1},
      'stores': 5,
      'stores_pending_verification': 1,
      'products': 69,
      'orders': {'created': 1, 'payment_verified': 1, 'preparing': 1, 'shipped': 1, 'delivered': 1, 'closed': 1, 'cancelled': 0},
      'gmv': 1566.07,
      'feedback_open': 2,
    },
    '/admin/users': {
      'total': 1,
      'items': [
        {'id': 1, 'name': 'Administrador', 'email': 'admin@demo.pe', 'role': 'admin', 'is_active': true},
      ],
    },
    '/admin/stores': [
      {
        'id': 5, 'business_name': 'Todo Moto JLO', 'district': 'Jose L. Ortiz', 'verified': false,
        'ruc': '20601234565', 'address': 'Av. Chinchaysuyo 1580', 'rating_avg': 4.1, 'rating_count': 7,
        'owner': {'id': 6, 'name': 'Proveedor 5', 'email': 'proveedor5@demo.pe', 'role': 'supplier'},
      },
    ],
    '/admin/orders': [
      {
        'id': 6, 'code': 'CTR-000006', 'status': 'closed', 'status_label': 'Cerrado', 'next_status': [],
        'subtotal': 100.0, 'shipping_cost': 10.0, 'total': 110.0, 'payment_method': 'card',
        'created_at': '2026-09-08T00:35:14', 'updated_at': '2026-09-08T00:35:14',
        'store': {'id': 1, 'business_name': 'Repuestos El Motociclista SAC'},
        'buyer': {'id': 7, 'name': 'Taller Julio', 'phone': null, 'email': 'j@x.pe'},
        'items': [], 'events': [],
      },
    ],
    '/admin/feedback': [
      {
        'id': 1, 'subject': 'Filtro por cilindrada', 'message': 'Seria util', 'resolved': false,
        'created_at': '2026-09-08T00:35:14',
        'user': {'id': 7, 'name': 'Taller Julio', 'email': 'j@x.pe', 'role': 'buyer'},
      },
    ],
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? body, Future<void>? cancel) async {
    final data = _routes[options.path];
    return ResponseBody.fromString(
      jsonEncode(data ?? {'detail': 'sin ruta ${options.path}'}),
      data == null ? 404 : 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('el panel admin monta sus 5 pestañas con datos del backend', (tester) async {
    final api = ApiClient(dio: Dio()..httpClientAdapter = _FakeAdapter());
    final auth = AuthRepository(api);
    await tester.pumpWidget(
      AppScope(
        api: api,
        session: Session(api, auth),
        auth: auth,
        catalog: CatalogRepository(api),
        orders: OrderRepository(api),
        suppliers: SupplierRepository(api),
        admin: AdminRepository(api),
        cart: CartStore(),
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const AdminShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Compradores'), findsOneWidget);
    for (final (i, text) in ['admin@demo.pe', 'Todo Moto JLO', 'CTR-000006', 'Filtro por cilindrada'].indexed) {
      await tester.tap(find.byType(NavigationDestination).at(i + 1));
      await tester.pumpAndSettle();
      expect(find.textContaining(text), findsWidgets, reason: 'pestaña ${i + 1}');
    }
    expect(tester.takeException(), isNull);
  });
}
