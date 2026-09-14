import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/domain/store.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../../main.dart' show shopMode;
import 'payment_config_page.dart';
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

  static const _titles = ['Mi tienda', 'Pedidos de mi tienda', 'Mis repuestos'];

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
                TextButton.icon(
                  onPressed: () => shopMode.value = true,
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                  label: const Text('Comprar', style: TextStyle(color: Colors.white)),
                ),
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
                _StoreTab(
                  store: store,
                  onEdited: () => setState(() => _reload++),
                ),
                const OrdersView(),
                const _SupplierProducts(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.storefront), label: 'Tienda'),
                NavigationDestination(
                    icon: Icon(Icons.inbox_outlined), label: 'Pedidos'),
                NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined), label: 'Repuestos'),
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
    // La lista no trae compatibilidades: se pide el producto completo para
    // que el formulario (y su PUT) no las pierda.
    Product? full = product;
    if (product != null) {
      try {
        full = await AppScope.suppliersOf(context).product(product.id);
      } catch (e) {
        if (mounted) showError(context, e);
        return;
      }
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormPage(product: full)),
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
    final scope = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!store.verified)
          Card(
            color: Colors.orange.withValues(alpha: 0.15),
            child: const ListTile(
              leading: Icon(Icons.pending_actions, color: Colors.orange),
              title: Text('Tienda pendiente de verificación'),
              subtitle: Text('El administrador revisa tu RUC. Ya puedes publicar; '
                  'la insignia de verificada aparece cuando lo apruebe.'),
            ),
          ),
        // Resumen del negocio
        AsyncView<Map<String, dynamic>>(
          refreshKey: store.id,
          load: scope.suppliers.dashboard,
          builder: (context, d) {
            final byStatus = (d['orders_by_status'] as Map).cast<String, dynamic>();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _Kpi(label: 'Por despachar', value: '${d['pending_to_ship']}', icon: Icons.local_shipping_outlined),
                    _Kpi(label: 'Repuestos', value: '${d['products']}', icon: Icons.inventory_2_outlined),
                    _Kpi(label: 'Sin stock', value: '${d['out_of_stock']}', icon: Icons.remove_shopping_cart_outlined),
                    _Kpi(label: 'Vendido', value: soles((d['total_sold'] as num?) ?? 0), icon: Icons.payments_outlined),
                    _Kpi(label: 'Cerrados', value: '${byStatus['closed'] ?? 0}', icon: Icons.task_alt),
                  ].map((k) => Expanded(child: k)).toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(store.businessName,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    if (store.verified)
                      const Icon(Icons.verified_user, color: Colors.blue),
                  ],
                ),
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
                    icon: Icons.map_outlined,
                    text: store.hasLocation
                        ? 'Ubicación: ${store.latitude}, ${store.longitude}'
                        : 'Sin ubicación en el mapa'),
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
        const SizedBox(height: 8),
        // Medio de cobro: nucleo del modelo de negocio
        Card(
          child: ListTile(
            leading: Icon(
              store.paymentConfigured ? Icons.credit_score : Icons.credit_card_off_outlined,
              color: store.paymentConfigured ? Colors.green : Colors.orange,
            ),
            title: const Text('Medio de cobro'),
            subtitle: Text(switch (store.paymentProvider) {
              'mercadopago' => 'Mercado Pago · configurado',
              'niubiz' => 'Niubiz · configurado',
              _ => 'Sin pasarela: los pagos con tarjeta se simulan',
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => PaymentConfigPage(store: store)),
              );
              if (saved == true) onEdited();
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('Estados del pedido', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final st in orderTimeline)
          Row(
            children: [
              Icon(orderStatusIcon(st), size: 16, color: orderStatusColor(st)),
              const SizedBox(width: 8),
              Text(orderStatusLabel(st), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
        ],
      );
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
