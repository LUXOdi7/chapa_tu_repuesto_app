import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/domain/store.dart';
import '../../orders/presentation/orders_page.dart';
import 'product_form_page.dart';
import 'store_form_page.dart';

/// Panel del proveedor: bandeja de pedidos de su tienda, sus repuestos y los
/// datos del negocio.
///
/// Si todavia no registro la tienda (`/suppliers/store` responde 404) la app lo
/// manda al formulario antes de dejarlo hacer nada mas.
class SupplierShell extends StatefulWidget {
  const SupplierShell({super.key});

  @override
  State<SupplierShell> createState() => _SupplierShellState();
}

class _SupplierShellState extends State<SupplierShell> {
  int _tab = 0;
  int _reload = 0;

  static const _titles = ['Pedidos de mi tienda', 'Mis repuestos', 'Mi tienda'];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      body: AsyncView<Store?>(
        refreshKey: _reload,
        load: () => scope.suppliers.myStore(),
        builder: (context, store) {
          if (store == null) {
            // Sin tienda no puede publicar ni recibir pedidos: primero el alta.
            return StoreFormPage(
              onSaved: () => setState(() => _reload++),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(_titles[_tab]),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  onPressed: scope.session.signOut,
                ),
              ],
            ),
            body: IndexedStack(
              index: _tab,
              children: [
                const OrdersView(),
                const _SupplierProducts(),
                _StoreTab(
                  store: store,
                  onEdited: () => setState(() => _reload++),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.inbox_outlined), label: 'Pedidos'),
                NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined), label: 'Repuestos'),
                NavigationDestination(
                    icon: Icon(Icons.storefront), label: 'Tienda'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupplierProducts extends StatefulWidget {
  const _SupplierProducts();

  @override
  State<_SupplierProducts> createState() => _SupplierProductsState();
}

class _SupplierProductsState extends State<_SupplierProducts> {
  int _reload = 0;

  Future<void> _open([Product? product]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormPage(product: product)),
    );
    if (saved == true && mounted) setState(() => _reload++);
  }

  Future<void> _delete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Dar de baja "${product.name}"?'),
        content: const Text('Deja de aparecer en el catálogo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AppScope.suppliersOf(context).deleteProduct(product.id);
      if (mounted) setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      body: AsyncView<List<Product>>(
        refreshKey: _reload,
        load: scope.suppliers.myProducts,
        isEmpty: (products) => products.isEmpty,
        emptyIcon: Icons.inventory_2_outlined,
        emptyMessage: 'Todavía no publicaste repuestos.',
        builder: (context, products) => ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final product = products[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: PartImage(path: product.imageUrl, height: 48),
                ),
              ),
              title: Text(product.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${product.partCode}  ·  '
                  '${soles(product.price)}  ·  stock ${product.stock}'
                  '${product.isActive ? '' : '  ·  oculto'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(product),
              ),
              onTap: () => _open(product),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
    );
  }
}

class _StoreTab extends StatelessWidget {
  const _StoreTab({required this.store, required this.onEdited});

  final Store store;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).session.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.businessName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(store.ratingLabel),
                const Divider(height: 24),
                _Line(icon: Icons.badge_outlined, text: 'RUC ${store.ruc ?? '-'}'),
                _Line(
                    icon: Icons.location_on_outlined,
                    text: [store.address, store.district]
                        .whereType<String>()
                        .join(', ')),
                _Line(
                    icon: Icons.phone_outlined, text: store.phone ?? 'Sin teléfono'),
                _Line(
                    icon: Icons.schedule,
                    text: store.openingHours ?? 'Horario no indicado'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => StoreFormPage(store: store)),
            );
            if (saved == true) onEdited();
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar datos de la tienda'),
        ),
        const SizedBox(height: 24),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.name),
            subtitle: Text(user.email),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
