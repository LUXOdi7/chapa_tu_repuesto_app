import 'package:flutter/widgets.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/session.dart';
import '../features/cart/presentation/cart_store.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/orders/data/order_repository.dart';
import '../features/supplier/data/supplier_repository.dart';
import 'network/api_client.dart';

/// Inyeccion de dependencias con `InheritedWidget`, que ya viene en Flutter.
/// Las pantallas se redibujan con `ListenableBuilder` sobre el store concreto
/// (sesion o carrito), asi que aqui no hace falta notificar nada.
/// ponytail: sustituir por get_it/Riverpod cuando haya scopes por feature; con
/// dos objetos con estado (sesion y carrito) no aporta nada.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.session,
    required this.auth,
    required this.catalog,
    required this.orders,
    required this.suppliers,
    required this.cart,
    required super.child,
  });

  final ApiClient api;
  final Session session;
  final AuthRepository auth;
  final CatalogRepository catalog;
  final OrderRepository orders;
  final SupplierRepository suppliers;
  final CartStore cart;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado: falta envolver MaterialApp');
    return scope!;
  }

  static Session sessionOf(BuildContext c) => of(c).session;
  static CatalogRepository catalogOf(BuildContext c) => of(c).catalog;
  static OrderRepository ordersOf(BuildContext c) => of(c).orders;
  static SupplierRepository suppliersOf(BuildContext c) => of(c).suppliers;
  static CartStore cartOf(BuildContext c) => of(c).cart;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      session != oldWidget.session ||
      cart != oldWidget.cart;
}
