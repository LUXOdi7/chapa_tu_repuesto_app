import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/app_theme.dart';
import 'core/network/api_client.dart';

import 'package:firebase_core/firebase_core.dart';

import 'features/admin/data/admin_repository.dart';
import 'features/admin/presentation/admin_shell.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/session.dart';
import 'features/cart/presentation/cart_page.dart';
import 'features/cart/presentation/cart_store.dart';
import 'features/cart/presentation/checkout_page.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/catalog/presentation/product_detail_page.dart';
import 'features/catalog/presentation/search_page.dart';
import 'features/catalog/presentation/store_page.dart';
import 'features/orders/data/order_repository.dart';
import 'features/orders/presentation/order_tracking_page.dart';
import 'features/orders/presentation/orders_page.dart';
import 'features/orders/presentation/receipt_page.dart';
import 'features/profile/presentation/legal_page.dart';
import 'features/profile/presentation/notifications_page.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/supplier/data/supplier_repository.dart';
import 'features/supplier/presentation/supplier_shell.dart';
import 'core/notifications/firebase_notifications.dart';
import 'shared/widgets/app_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push solo en movil: en web falta firebase_options.dart y el service worker,
  // y un initializeApp() sin opciones tumba la app ANTES de runApp (pantalla en
  // blanco). El try/catch deja arrancar tambien a quien no tenga
  // google-services.json: sin push, pero con app.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      await FirebaseNotifications.initialize();
    } catch (error) {
      debugPrint('Firebase no disponible, se sigue sin push: $error');
    }
  }

  runApp(const ChapaTuRepuestoApp());
}

/// Tema claro/oscuro conmutable. Un `ValueNotifier` global evita montar un
/// gestor de estado entero para un unico switch de UI.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Proveedor en "modo comprador": ve la app como un comprador (busca, carrito,
/// sus compras) y vuelve a su panel con un toque. Solo UI; el backend ya deja
/// comprar a un proveedor (menos en su propia tienda).
final shopMode = ValueNotifier<bool>(false);

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
  late final _admin = AdminRepository(_api);
  late final _session = Session(_api, _auth);
  final _cart = CartStore();

  @override
  void initState() {
    super.initState();
    // Token guardado + carrito guardado: la app arranca donde se quedo.
    _session.loadCategories = _catalog.loadCategories;
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
      admin: _admin,
      cart: _cart,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'ChapaTuRepuesto',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          home: const _WebIdleRoot(),
          onGenerateRoute: _generateRoute,
        ),
      ),
    );
  }

  /// Rutas con argumentos tipados. ponytail: pasar a go_router si aparecen
  /// deep links (p. ej. volver de la pasarela directo al pedido).
  Route<dynamic>? _generateRoute(RouteSettings settings) =>
      switch (settings.name) {
        ProductDetailPage.route => MaterialPageRoute<void>(
          builder: (_) =>
              ProductDetailPage(productId: settings.arguments! as int),
        ),
        StorePage.route => MaterialPageRoute<void>(
          builder: (_) => StorePage(storeId: settings.arguments! as int),
        ),
        CheckoutPage.route => MaterialPageRoute<void>(
          builder: (_) => const CheckoutPage(),
        ),
        OrderTrackingPage.route => MaterialPageRoute<void>(
          builder: (_) =>
              OrderTrackingPage(orderId: settings.arguments! as int),
        ),
        ReceiptPage.route => MaterialPageRoute<void>(
          builder: (_) => ReceiptPage(orderId: settings.arguments! as int),
        ),
        ProfilePage.route => MaterialPageRoute<void>(
          builder: (_) => const ProfilePage(),
        ),
        LegalPage.route => MaterialPageRoute<void>(
          builder: (_) => LegalPage(
            section: (settings.arguments as String?) ?? 'about',
          ),
        ),
        _ => null,
      };
}

/// En web: cierra la sesion tras 30 min sin actividad del puntero.
/// En movil: transparente (no hay riesgo de sesion olvidada en un navegador).
class _WebIdleRoot extends StatefulWidget {
  const _WebIdleRoot();

  @override
  State<_WebIdleRoot> createState() => _WebIdleRootState();
}

class _WebIdleRootState extends State<_WebIdleRoot> {
  Timer? _idleTimer;
  static const _timeout = Duration(minutes: 30);

  void _reset() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_timeout, () {
      if (mounted) AppScope.sessionOf(context).signOut();
    });
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _reset();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const _Root();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      onPointerMove: (_) => _reset(),
      child: const _Root(),
    );
  }
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
          return const Scaffold(body: Center(child: BrandLogo(height: 180)));
        }
        final user = session.user;
        if (user == null) {
          shopMode.value = false;
          return const LoginPage();
        }
        if (user.isAdmin) return const AdminShell();
        if (!user.isSupplier) return const BuyerShell();
        return ValueListenableBuilder<bool>(
          valueListenable: shopMode,
          builder: (context, buying, _) => buying
              ? const BuyerShell(asSupplier: true)
              : const SupplierShell(),
        );
      },
    );
  }
}

/// Contenedor de las 4 pestañas del comprador. Un `IndexedStack` conserva el
/// scroll y los filtros al cambiar de pestaña.
class BuyerShell extends StatefulWidget {
  const BuyerShell({super.key, this.asSupplier = false});

  /// Proveedor en modo comprador: muestra el boton para volver a su panel y
  /// pide sus compras (no la bandeja de su tienda) en "Pedidos".
  final bool asSupplier;

  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _tab = 0;

  static const _titles = [
    'ChapaTuRepuesto',
    'Tiendas',
    'Mi carrito',
    'Mis pedidos',
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    // El badge del carrito esta dentro de los destinos, asi que el shell
    // completo escucha al carrito (antes solo lo hacia la barra inferior).
    return ListenableBuilder(
      listenable: scope.cart,
      builder: (context, _) => AdaptiveScaffold(
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
        appBar: AppBar(
          title: BrandTitle(_titles[_tab]),
          actions: [
            if (widget.asSupplier)
              TextButton.icon(
                onPressed: () => shopMode.value = false,
                icon: const Icon(Icons.storefront, color: Colors.white),
                label: const Text(
                  'Mi tienda',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            const NotificationBell(),
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.pushNamed(context, ProfilePage.route),
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            const SearchView(),
            const StoresView(),
            const CartView(),
            OrdersView(asBuyer: widget.asSupplier),
          ],
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Tiendas',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: scope.cart.unitCount,
              isLabelVisible: scope.cart.unitCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: 'Carrito',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
        ],
      ),
    );
  }
}
