import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/cart_item.dart';
import 'cart_store.dart';
import 'checkout_page.dart';

/// Carrito agrupado por tienda: cada proveedor genera su propio pedido, asi que
/// el comprador ve desde aqui en cuantos pedidos se va a dividir y cuanto envio
/// paga por cada uno.
class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = AppScope.cartOf(context);

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final groups = cart.groups;
        if (groups.isEmpty) {
          return const EmptyState(
            message: 'Tu carrito está vacío',
            icon: Icons.shopping_cart_outlined,
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  for (final group in groups)
                    _StoreGroup(
                      group: group,
                      onQuantity: cart.setQuantity,
                      onRemove: cart.remove,
                    ),
                ],
              ),
            ),
            _CartSummary(
              orderCount: groups.length,
              subtotal: cart.subtotal,
              shipping: cart.shipping,
              total: cart.total,
              onCheckout: () => Navigator.pushNamed(context, CheckoutPage.route),
            ),
          ],
        );
      },
    );
  }
}

class _StoreGroup extends StatelessWidget {
  const _StoreGroup({
    required this.group,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartGroup group;
  final void Function(int productId, int quantity) onQuantity;
  final void Function(int productId) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = group.store;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: const Icon(Icons.storefront, size: 20),
            ),
            title: Text(store.businessName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([store.district, store.distanceLabel]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join('  ·  ')),
            trailing: const Chip(
              label: Text('1 pedido'),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Divider(height: 1),
          for (final item in group.items)
            _CartRow(
              item: item,
              onQuantity: (q) => onQuantity(item.product.id, q),
              onRemove: () => onRemove(item.product.id),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                _Line(label: 'Subtotal', value: soles(group.subtotal)),
                _Line(
                  label: 'Envío',
                  value: group.shipping == 0
                      ? 'Gratis'
                      : soles(group.shipping),
                  hint: group.shipping == 0
                      ? null
                      : 'Gratis desde ${soles(kFreeShippingFrom)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hint == null ? label : '$label  ($hint)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartItem item;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: PartImage(path: product.imageUrl, height: 52),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${product.partCode}  ${soles(product.price)} c/u',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          _QuantityStepper(
            quantity: item.quantity,
            max: product.stock,
            onChanged: onQuantity,
          ),
          IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => onChanged(quantity - 1),
          ),
          Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            // Tope duro en el stock que reporto el backend.
            onPressed: quantity >= max ? null : () => onChanged(quantity + 1),
          ),
        ],
      );
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.orderCount,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.onCheckout,
  });

  final int orderCount;
  final double subtotal;
  final double shipping;
  final double total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orderCount == 1
                          ? 'Se generará 1 pedido'
                          : 'Se generarán $orderCount pedidos (uno por tienda)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(soles(total),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Productos ${soles(subtotal)}  ·  Envío ${soles(shipping)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Ir a pagar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
