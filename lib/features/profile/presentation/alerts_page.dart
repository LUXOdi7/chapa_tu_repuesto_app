import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_widgets.dart';

/// Mis alertas de stock / precio. Se crean desde la ficha del repuesto
/// (campana); aquí se ven y se borran. El aviso llega por correo.
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.catalogOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis alertas')),
      body: AsyncView<List<Map<String, dynamic>>>(
        refreshKey: _reload,
        load: catalog.alerts,
        isEmpty: (a) => a.isEmpty,
        emptyIcon: Icons.notifications_none,
        emptyMessage: 'Sin alertas. Crea una desde la campana en la ficha de un repuesto.',
        builder: (context, alerts) => ListView.separated(
          itemCount: alerts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = alerts[i];
            final fired = a['fired_at'] != null;
            final maxPrice = asDouble(a['max_price']);
            return ListTile(
              leading: Icon(
                fired ? Icons.notifications_active : Icons.notifications_none,
                color: fired ? Colors.green : null,
              ),
              title: Text('${a['product_name']}  (${a['part_code']})'),
              subtitle: Text(
                [
                  if (a['notify_stock'] == true) 'con stock',
                  if (maxPrice != null) 'precio ≤ ${soles(maxPrice)}',
                  fired ? 'AVISADA' : 'esperando',
                ].join('  ·  '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  try {
                    await catalog.deleteAlert(a['id'] as int);
                    if (context.mounted) setState(() => _reload++);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Diálogo "Avísame": se abre desde la ficha del repuesto.
Future<void> showCreateAlertDialog(
  BuildContext context, {
  required String partCode,
  required double price,
}) async {
  final catalog = AppScope.catalogOf(context);
  final priceCtrl = TextEditingController();
  var notifyStock = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setLocal) => AlertDialog(
        title: const Text('Avísame'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: notifyStock,
              onChanged: (v) => setLocal(() => notifyStock = v ?? true),
              title: const Text('Cuando haya stock'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cuando baje de S/ (opcional)',
                hintText: 'Hoy: ${soles(price)}',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Te avisamos por correo en cuanto una tienda cumpla la condición.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Crear alerta'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await catalog.createAlert(
      partCode: partCode,
      maxPrice: double.tryParse(priceCtrl.text.replaceAll(',', '.')),
      notifyStock: notifyStock,
    );
    if (context.mounted) {
      showInfo(context, 'Alerta creada. Revísalas en Mi cuenta → Mis alertas.');
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
