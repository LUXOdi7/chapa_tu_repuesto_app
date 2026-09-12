import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/app_theme.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/session.dart';
import 'features/cart/presentation/cart_page.dart';
import 'features/cart/presentation/cart_store.dart';
import 'features/cart/presentation/checkout_page.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/catalog/presentation/product_detail_page.dart';
import 'features/catalog/presentation/search_page.dart';
import 'features/orders/data/order_repository.dart';
import 'features/orders/presentation/order_tracking_page.dart';
import 'features/orders/presentation/orders_page.dart';
import 'features/orders/presentation/receipt_page.dart';
import 'features/supplier/data/supplier_repository.dart';
import 'features/supplier/presentation/supplier_shell.dart';

void main() => runApp(const ChapaTuRepuestoApp());

/// Tema claro/oscuro conmutable. Un `ValueNotifier` global evita montar un
/// gestor de estado entero para un unico switch de UI.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

class ChapaTuRepuestoApp extends StatefulWidget {
  const ChapaTuRepuestoApp({super.key});

  @override
  State<ChapaTuRepuestoApp> createState() => _ChapaTuRepuestoAppState();
}

class _ChapaTuRepuestoAppState extends State<ChapaTuRepuestoApp> {
  // Instancias de vida larga: se crean una vez y viven en el AppScope.
  final _api = ApiClient();
  late final _auth = AuthRepository(_api);
  late final _catalog = CatalogRepository(_api);
  late final _orders = OrderRepository(_api);
  late final _suppliers = SupplierRepository(_api);
  late final _session = Session(_api, _auth);
  final _cart = CartStore();

  @override
  void initState() {
    super.initState();
    // Token guardado + carrito guardado: la app arranca donde se quedo.
    _session.restore();
    _cart.restore();
  }

  @override
  void dispose() {
    _session.dispose();
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: _api,
      session: _session,
      auth: _auth,
      catalog: _catalog,
      orders: _orders,
      suppliers: _suppliers,
      cart: _cart,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'ChapaTuRepuesto',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          home: const _Root(),
          onGenerateRoute: _generateRoute,
        ),
      ),
    );
  }

  /// Rutas con argumentos tipados. `onGenerateRoute` basta para cuatro
  /// destinos: ponytail: pasar a go_router si aparecen deep links.
  Route<dynamic>? _generateRoute(RouteSettings settings) =>
      switch (settings.name) {
        ProductDetailPage.route => MaterialPageRoute<void>(
            builder: (_) =>
                ProductDetailPage(productId: settings.arguments! as int),
          ),
        CheckoutPage.route =>
          MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
        OrderTrackingPage.route => MaterialPageRoute<void>(
            builder: (_) =>
                OrderTrackingPage(orderId: settings.arguments! as int),
          ),
        ReceiptPage.route => MaterialPageRoute<void>(
            builder: (_) => ReceiptPage(orderId: settings.arguments! as int),
          ),
        _ => null,
      };
}

/// Decide que ve el usuario: splash mientras se valida el token guardado,
/// login si no hay sesion, y despues el panel que corresponda a su perfil.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.sessionOf(context);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.restoring) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = session.user;
        if (user == null) return const LoginPage();
        return user.isSupplier ? const SupplierShell() : const BuyerShell();
      },
    );
  }
}

/// Contenedor de las 3 pantallas del comprador. Un `IndexedStack` conserva el
/// scroll y los filtros al cambiar de pestaña.
class BuyerShell extends StatefulWidget {
  const BuyerShell({super.key});

  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _tab = 0;

  static const _titles = ['ChapaTuRepuesto', 'Mi carrito', 'Mis pedidos'];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () => themeMode.value =
                Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (_) => scope.session.signOut(),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(scope.session.user?.name ?? ''),
              ),
              const PopupMenuItem(value: 'out', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [SearchView(), CartView(), OrdersView()],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: scope.cart,
        builder: (context, _) => NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.search), label: 'Buscar'),
            NavigationDestination(
              icon: Badge.count(
                count: scope.cart.unitCount,
                isLabelVisible: scope.cart.unitCount > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              label: 'Carrito',
            ),
            const NavigationDestination(
                icon: Icon(Icons.receipt_long), label: 'Pedidos'),
          ],
        ),
      ),
    );
  }
}
