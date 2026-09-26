import 'dart:typed_data';

import 'package:chapa_tu_repuesto_app/core/app_scope.dart';
import 'package:chapa_tu_repuesto_app/core/app_theme.dart';
import 'package:chapa_tu_repuesto_app/core/network/api_client.dart';
import 'package:chapa_tu_repuesto_app/features/admin/data/admin_repository.dart';
import 'package:chapa_tu_repuesto_app/features/auth/data/auth_repository.dart';
import 'package:chapa_tu_repuesto_app/features/auth/presentation/session.dart';
import 'package:chapa_tu_repuesto_app/features/cart/presentation/cart_store.dart';
import 'package:chapa_tu_repuesto_app/features/catalog/data/catalog_repository.dart';
import 'package:chapa_tu_repuesto_app/features/orders/data/order_repository.dart';
import 'package:chapa_tu_repuesto_app/features/supplier/data/supplier_repository.dart';
import 'package:chapa_tu_repuesto_app/features/supplier/presentation/stats_page.dart';
import 'package:chapa_tu_repuesto_app/shared/widgets/charts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuesta REAL de `GET /suppliers/stats?days=30` (volcada del backend con
/// 4 repuestos, 3 pedidos pagados y 2 compradores). Si el contrato cambia,
/// este test se cae antes que la presentacion.
const _statsJson = r'''
{"days": 30, "since": "2026-08-28", "totals": {"revenue": 580.0, "orders": 3, "units": 8, "avg_ticket": 193.33333333333334, "cancelled": 0, "buyers": 2, "rating_avg": 0.0, "rating_count": 0}, "by_day": [{"day": "2026-08-28", "orders": 0, "total": 0.0}, {"day": "2026-08-29", "orders": 0, "total": 0.0}, {"day": "2026-08-30", "orders": 0, "total": 0.0}, {"day": "2026-08-31", "orders": 0, "total": 0.0}, {"day": "2026-09-01", "orders": 0, "total": 0.0}, {"day": "2026-09-02", "orders": 0, "total": 0.0}, {"day": "2026-09-03", "orders": 0, "total": 0.0}, {"day": "2026-09-04", "orders": 0, "total": 0.0}, {"day": "2026-09-05", "orders": 0, "total": 0.0}, {"day": "2026-09-06", "orders": 0, "total": 0.0}, {"day": "2026-09-07", "orders": 0, "total": 0.0}, {"day": "2026-09-08", "orders": 0, "total": 0.0}, {"day": "2026-09-09", "orders": 0, "total": 0.0}, {"day": "2026-09-10", "orders": 0, "total": 0.0}, {"day": "2026-09-11", "orders": 0, "total": 0.0}, {"day": "2026-09-12", "orders": 0, "total": 0.0}, {"day": "2026-09-13", "orders": 0, "total": 0.0}, {"day": "2026-09-14", "orders": 0, "total": 0.0}, {"day": "2026-09-15", "orders": 0, "total": 0.0}, {"day": "2026-09-16", "orders": 0, "total": 0.0}, {"day": "2026-09-17", "orders": 0, "total": 0.0}, {"day": "2026-09-18", "orders": 0, "total": 0.0}, {"day": "2026-09-19", "orders": 0, "total": 0.0}, {"day": "2026-09-20", "orders": 0, "total": 0.0}, {"day": "2026-09-21", "orders": 0, "total": 0.0}, {"day": "2026-09-22", "orders": 0, "total": 0.0}, {"day": "2026-09-23", "orders": 0, "total": 0.0}, {"day": "2026-09-24", "orders": 0, "total": 0.0}, {"day": "2026-09-25", "orders": 0, "total": 0.0}, {"day": "2026-09-26", "orders": 3, "total": 580.0}], "by_status": {"created": 0, "payment_verified": 3, "preparing": 0, "shipped": 0, "delivered": 0, "closed": 0, "cancelled": 0}, "top_products": [{"product_id": 4, "name": "Casco integral", "brand": "LS2", "units": 1, "total": 210.0}, {"product_id": 3, "name": "Bujía iridium", "brand": "NGK", "units": 4, "total": 130.0}, {"product_id": 2, "name": "Kit de arrastre", "brand": "DID", "units": 1, "total": 120.0}, {"product_id": 1, "name": "Pastillas de freno", "brand": "Brembo", "units": 2, "total": 90.0}], "by_category": [{"category": "accesorios", "units": 1, "total": 210.0}, {"category": "motor", "units": 4, "total": 130.0}, {"category": "transmision", "units": 1, "total": 120.0}, {"category": "frenos", "units": 2, "total": 90.0}], "top_buyers": [{"name": "Taller Don Julio", "orders": 2, "total": 440.0}, {"name": "Motos Express", "orders": 1, "total": 140.0}], "low_stock": [{"name": "Casco integral", "part_code": "PC-3", "stock": 1}]}
''';

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    final ok = options.path.startsWith('/suppliers/stats');
    return ResponseBody.fromString(
      ok ? _statsJson : '{"detail":"sin ruta"}',
      ok ? 200 : 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _app() {
  final api = ApiClient(dio: Dio()..httpClientAdapter = _FakeAdapter());
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
      home: const Scaffold(body: SupplierStatsView()),
    ),
  );
}

void main() {
  // Lienzo muy alto a proposito: asi el ListView construye TODOS los paneles
  // de una vez y el test ve los desbordes de cualquiera de ellos. El ancho es
  // el que manda en el layout, y es el real de cada dispositivo.
  for (final (nombre, size) in [
    ('celular', const Size(400, 3200)),
    ('escritorio', const Size(1400, 2600)),
  ]) {
    testWidgets('las estadisticas del proveedor se dibujan en $nombre', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Sin overflows ni excepciones al pintar barras, dona y rankings.
      expect(tester.takeException(), isNull);
      expect(find.byType(DailyBars), findsNWidgets(2));

      // Indicadores con los numeros reales del backend.
      expect(find.text('S/ 580.00'), findsWidgets); // vendido
      expect(find.text('8'), findsWidgets); // unidades

      expect(find.textContaining('Casco integral'), findsWidgets);
      expect(find.byType(RankingBars), findsNWidgets(3));
      expect(find.byType(DonutChart), findsOneWidget);
      // Aviso de reposicion: al casco le queda 1 unidad.
      expect(find.textContaining('Repuestos por reponer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cambiar la ventana a 7 dias recarga la serie', (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('7 días'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DailyBars), findsNWidgets(2));
  });
}
