import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../shared/widgets/app_widgets.dart';

/// Constancia de pago.
///
/// Se dibuja desde `/orders/{id}/receipt` (JSON) en vez de incrustar
/// `receipt.html`. ponytail: asi no entra `webview_flutter` (ni el lio de
/// pasarle el header Authorization al WebView) solo para mostrar una tabla.
/// Cambiar cuando haga falta imprimir o exportar a PDF: ahi el HTML del backend
/// ya viene listo.
///
/// El contenido se recorre generico: si el backend agrega un campo a la
/// constancia, aparece solo.
class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.orderId});

  static const route = '/receipt';

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Constancia')),
      body: AsyncView<Map<String, dynamic>>(
        load: () => scope.orders.receipt(orderId),
        builder: (context, receipt) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Center(
              child: Icon(Icons.receipt_long,
                  size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            ..._entries(context, receipt),
          ],
        ),
      ),
    );
  }

  List<Widget> _entries(BuildContext context, Map<String, dynamic> map) {
    final widgets = <Widget>[];
    map.forEach((key, value) {
      if (value == null) return;
      if (value is List) {
        widgets.add(SectionTitle(_label(key)));
        for (final element in value) {
          widgets.add(Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: element is Map
                    ? _entries(context, element.cast<String, dynamic>())
                    : [_Row(label: '', value: '$element')],
              ),
            ),
          ));
        }
      } else if (value is Map) {
        widgets.add(SectionTitle(_label(key)));
        widgets.addAll(_entries(context, value.cast<String, dynamic>()));
      } else {
        widgets.add(_Row(label: _label(key), value: '$value'));
      }
    });
    return widgets;
  }

  static const _labels = {
    'code': 'Código',
    'status': 'Estado',
    'status_label': 'Estado',
    'subtotal': 'Subtotal',
    'shipping_cost': 'Envío',
    'total': 'Total',
    'payment_method': 'Método de pago',
    'payment_op_number': 'N° de operación',
    'paid_at': 'Pagado el',
    'created_at': 'Creado el',
    'delivery_address': 'Dirección de entrega',
    'store': 'Tienda',
    'buyer': 'Comprador',
    'items': 'Productos',
    'business_name': 'Razón social',
    'product_name': 'Producto',
    'part_code': 'Código de parte',
    'brand': 'Marca',
    'unit_price': 'Precio unitario',
    'quantity': 'Cantidad',
    'name': 'Nombre',
    'email': 'Correo',
    'phone': 'Teléfono',
    'address': 'Dirección',
    'ruc': 'RUC',
    'notes': 'Notas',
  };

  static String _label(String key) =>
      _labels[key] ??
      (key.isEmpty
          ? key
          : key[0].toUpperCase() + key.substring(1).replaceAll('_', ' '));
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(label,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline)),
            ),
            Expanded(
              flex: 3,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}
