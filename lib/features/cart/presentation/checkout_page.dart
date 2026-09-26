import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/map_picker_page.dart';
import '../../auth/domain/user.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/payment_method.dart';
import '../../orders/presentation/order_tracking_page.dart';

/// Resumen + direccion + metodo de pago.
///
/// `/orders/checkout` DEVUELVE UNA LISTA: el backend parte el carrito en una
/// orden por proveedor. Por eso la confirmacion muestra los pedidos por
/// separado, cada uno con su codigo.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  static const route = '/checkout';

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  PaymentMethod _method = PaymentMethod.yape;
  bool _busy = false;

  /// true = usar la direccion guardada del perfil; false = una para este pedido.
  bool _useSaved = true;
  double? _lat;
  double? _lng;
  bool _loaded = false;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Con direccion guardada arranca en "usar la mía"; si no, en "otra".
  void _loadDefaults(User? user) {
    if (_loaded) return;
    _loaded = true;
    _useSaved = user?.hasSavedAddress ?? false;
    if (_useSaved) {
      _lat = user!.latitude;
      _lng = user.longitude;
    }
  }

  Future<void> _pickOnMap() async {
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (point == null || !mounted) return;
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
    });
  }

  Future<void> _submit() async {
    final scope = AppScope.of(context);
    final saved = scope.session.user;
    final address = _useSaved ? (saved?.address ?? '') : _address.text.trim();
    if (!_useSaved && !_formKey.currentState!.validate()) return;
    if (address.length < 6) {
      showInfo(context, 'Escribe la dirección de entrega');
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await scope.orders.checkout(
        items: scope.cart.items,
        deliveryAddress: address,
        paymentMethod: _method,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        deliveryLat: _lat,
        deliveryLng: _lng,
      );
      scope.cart.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _CreatedDialog(orders: created),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        OrderTrackingPage.route,
        arguments: created.first.id,
      );
    } catch (e) {
      // 409 = sin stock suficiente; el `detail` ya dice de que producto.
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = AppScope.cartOf(context);
    final groups = cart.groups;
    final saved = AppScope.sessionOf(context).user;
    _loadDefaults(saved);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FormBox(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SectionTitle('Resumen por tienda'),
              for (final group in groups)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.storefront),
                  title: Text(group.store.businessName),
                  subtitle: Text(
                    '${group.items.length} '
                    '${group.items.length == 1 ? "producto" : "productos"}  ·  '
                    'envío ${group.shipping == 0 ? "gratis" : soles(group.shipping)}',
                  ),
                  trailing: Text(
                    soles(group.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

              const SectionTitle('Entrega'),
              // Direccion guardada del perfil o una para este pedido; en ambos
              // casos se puede marcar el punto exacto en el mapa.
              if (saved?.hasSavedAddress ?? false) ...[
                RadioGroup<bool>(
                  groupValue: _useSaved,
                  onChanged: (v) => setState(() {
                    _useSaved = v ?? true;
                    _lat = _useSaved ? saved.latitude : null;
                    _lng = _useSaved ? saved.longitude : null;
                  }),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        title: const Text('Usar mi dirección guardada'),
                        subtitle: Text(saved!.address!),
                      ),
                      const RadioListTile<bool>(
                        value: false,
                        title: Text('Otra dirección para este pedido'),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (!_useSaved)
                      TextFormField(
                        controller: _address,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de entrega',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().length < 6)
                            ? 'Escribe la dirección del taller'
                            : null,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickOnMap,
                            icon: const Icon(Icons.map_outlined),
                            label: Text(
                              _lat == null
                                  ? 'Marcar punto en el mapa'
                                  : 'Cambiar punto del mapa',
                            ),
                          ),
                        ),
                        if (_lat != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Nota para el proveedor (opcional)',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined),
                      ),
                    ),
                  ],
                ),
              ),

              const SectionTitle('Método de pago'),
              for (final method in PaymentMethod.values)
                ListTile(
                  onTap: () => setState(() => _method = method),
                  selected: _method == method,
                  selectedTileColor: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.08),
                  leading: Icon(method.icon),
                  title: Text(method.label),
                  subtitle: Text(method.hint),
                  trailing: Icon(
                    _method == method
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _method == method
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),

              const SectionTitle('Total'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _TotalRow(label: 'Productos', value: soles(cart.subtotal)),
                    _TotalRow(
                      label:
                          'Envío (${groups.length} '
                          '${groups.length == 1 ? "tienda" : "tiendas"})',
                      value: soles(cart.shipping),
                    ),
                    const Divider(),
                    _TotalRow(
                      label: 'Total a pagar',
                      value: soles(cart.total),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: groups.isEmpty || _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Confirmar ${soles(cart.total)}'),
          ),
        ),
      ),
    );
  }
}

/// El carrito se partio: aqui se ve en cuantos pedidos y con que codigo quedo
/// cada uno.
class _CreatedDialog extends StatelessWidget {
  const _CreatedDialog({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
    title: Text(
      orders.length == 1 ? 'Pedido creado' : '${orders.length} pedidos creados',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (orders.length > 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Tu carrito tenía productos de varias tiendas, así que se '
              'generó un pedido por cada una.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final order in orders)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long),
            title: Text(
              order.code,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(order.store.businessName),
            trailing: Text(soles(order.total)),
          ),
      ],
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Ir a pagar'),
      ),
    ],
  );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
