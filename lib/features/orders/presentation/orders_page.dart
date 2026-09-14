import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/order.dart';
import 'order_tracking_page.dart';

/// Historial de pedidos. El backend decide que devuelve: al comprador sus
/// compras, al proveedor los pedidos de SU tienda. La pantalla es la misma.
class OrdersView extends StatefulWidget {
  const OrdersView({super.key, this.asBuyer = false});

  /// Un proveedor en "modo comprador" ve sus compras, no la bandeja de su tienda.
  final bool asBuyer;

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  String? _filter;
  int _reload = 0;

  static const _filters = {
    null: 'Todos',
    'created': 'Por pagar',
    'payment_verified': 'Pagados',
    'preparing': 'En preparación',
    'shipped': 'Despachados',
    'delivered': 'Entregados',
  };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final entry in _filters.entries) ...[
                FilterChip(
                  label: Text(entry.value),
                  selected: _filter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Order>>(
            refreshKey: '$_filter|$_reload|${widget.asBuyer}',
            load: () => scope.orders.list(statusFilter: _filter, asBuyer: widget.asBuyer),
            isEmpty: (orders) => orders.isEmpty,
            emptyIcon: Icons.receipt_long,
            emptyMessage: _filter == null
                ? 'Todavía no hay pedidos'
                : 'No hay pedidos en ese estado',
            builder: (context, orders) => RefreshIndicator(
              onRefresh: () async => setState(() => _reload++),
              child: ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final order = orders[i];
                  final color = orderStatusColor(order.status);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(orderStatusIcon(order.status),
                          size: 20, color: color),
                    ),
                    title: Text(order.code,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${order.store.businessName}  ·  ${order.statusLabel}\n'
                      '${shortDate(order.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(soles(order.total),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        OrderTrackingPage.route,
                        arguments: order.id,
                      );
                      // Al volver el estado pudo cambiar (pago, despacho...).
                      if (context.mounted) setState(() => _reload++);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
