import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/domain/store.dart';
import '../../catalog/presentation/store_page.dart';
import '../../orders/data/order_repository.dart' show YapeInfo;
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_page.dart';
import '../../profile/presentation/notifications_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../../main.dart' show shopMode;
import 'payment_config_page.dart';
import 'product_form_page.dart';
import 'stats_page.dart';
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

  static const _titles = [
    'Mi tienda',
    'Estadísticas',
    'Pedidos de mi tienda',
    'Mis repuestos',
    'Chat con Admin',
  ];

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
            return StoreFormPage(onSaved: () => setState(() => _reload++));
          }
          return AdaptiveScaffold(
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
            appBar: AppBar(
              title: BrandTitle(_titles[_tab]),
              actions: [
                TextButton.icon(
                  onPressed: () => shopMode.value = true,
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Comprar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const NotificationBell(),
                IconButton(
                  tooltip: 'Mi cuenta',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () =>
                      Navigator.pushNamed(context, ProfilePage.route),
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
                const SupplierStatsView(),
                const OrdersView(),
                const _SupplierProducts(),
                const _SupplierDirectChat(),
              ],
            ),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront),
                label: 'Tienda',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Estadísticas',
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                label: 'Pedidos',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Repuestos',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_outlined),
                label: 'Chat',
              ),
            ],
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
        builder: (context, products) {
          // Agrupado por categoria; dentro, alfabetico. Tocar la categoria
          // despliega sus repuestos.
          final byCat = <String, List<Product>>{};
          for (final p in products) {
            byCat.putIfAbsent(p.category, () => []).add(p);
          }
          final cats = byCat.keys.toList()
            ..sort((a, b) => categoryLabel(a).compareTo(categoryLabel(b)));
          for (final list in byCat.values) {
            list.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final cat in cats)
                ExpansionTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(
                    categoryLabel(cat),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${byCat[cat]!.length} repuesto${byCat[cat]!.length == 1 ? '' : 's'}',
                  ),
                  children: [
                    for (final product in byCat[cat]!)
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: PartImage(
                              path: product.imageUrl,
                              height: 48,
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${product.partCode}  ·  '
                          '${soles(product.price)}  ·  stock ${product.stock}'
                          '${product.isActive ? '' : '  ·  oculto'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(product),
                        ),
                        onTap: () => _open(product),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
    );
  }
}

Future<void> _showSubscriptionPayment(BuildContext context, Store store) async {
  final repo = AppScope.ordersOf(context);
  YapeInfo? yape;
  try { yape = await repo.yapeInfo(); } catch (_) {}
  if (!context.mounted) return;
  final scheme = Theme.of(context).colorScheme;
  final ref = 'SUB-${store.businessName.substring(0, store.businessName.length.clamp(0, 15))}';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pagar suscripción S/ 100'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (yape?.qrImage != null && yape!.qrImage!.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.network(yape.qrImage!, height: 220,
                  errorBuilder: (_, _, _) => const Icon(Icons.qr_code_2, size: 120, color: Colors.grey)),
              )
            else
              const Icon(Icons.qr_code_2, size: 120, color: Colors.grey),
            const SizedBox(height: 12),
            if (yape != null && yape.phone.isNotEmpty) ...[
              const Text('Paga al número:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: yape!.phone));
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Número copiado')));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(yape.phone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, size: 18),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Text('Pon esta referencia en Yape:',
                  style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
                  textAlign: TextAlign.center),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: ref));
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Referencia copiada')));
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(ref, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSecondaryContainer)),
                    const SizedBox(width: 6),
                    Icon(Icons.copy, size: 18, color: scheme.onSecondaryContainer),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Monto: S/ 100.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Después de pagar, envía la captura al chat con el administrador. '
              'El admin activará tu suscripción por 30 días.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
    ),
  );
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
              subtitle: Text(
                'El administrador revisa tu RUC. Ya puedes publicar; '
                'la insignia de verificada aparece cuando lo apruebe.',
              ),
            ),
          ),
        if (!store.subscriptionActive)
          Card(
            color: Colors.red.withValues(alpha: 0.10),
            child: ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.red),
              title: const Text('Suscripción mensual inactiva'),
              subtitle: Text(
                store.subscriptionDaysLeft > -900
                    ? 'Venció hace ${-store.subscriptionDaysLeft} día${-store.subscriptionDaysLeft == 1 ? '' : 's'}.'
                    : 'Tu suscripción mensual no está activada todavía (S/ 100/mes).',
              ),
              trailing: FilledButton(
                onPressed: () => _showSubscriptionPayment(context, store),
                child: const Text('Pagar'),
              ),
            ),
          ),
        // Resumen del negocio
        AsyncView<Map<String, dynamic>>(
          refreshKey: store.id,
          load: scope.suppliers.dashboard,
          builder: (context, d) {
            final byStatus = (d['orders_by_status'] as Map)
                .cast<String, dynamic>();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _Kpi(
                      label: 'Por despachar',
                      value: '${d['pending_to_ship']}',
                      icon: Icons.local_shipping_outlined,
                    ),
                    _Kpi(
                      label: 'Repuestos',
                      value: '${d['products']}',
                      icon: Icons.inventory_2_outlined,
                    ),
                    _Kpi(
                      label: 'Sin stock',
                      value: '${d['out_of_stock']}',
                      icon: Icons.remove_shopping_cart_outlined,
                    ),
                    _Kpi(
                      label: 'Vendido',
                      value: soles((d['total_sold'] as num?) ?? 0),
                      icon: Icons.payments_outlined,
                    ),
                    _Kpi(
                      label: 'Cerrados',
                      value: '${byStatus['closed'] ?? 0}',
                      icon: Icons.task_alt,
                    ),
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
                      child: Text(
                        store.businessName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (store.verified)
                      const Icon(Icons.verified_user, color: Colors.blue),
                  ],
                ),
                const SizedBox(height: 4),
                Text(store.ratingLabel),
                const Divider(height: 24),
                _Line(
                  icon: Icons.badge_outlined,
                  text: 'RUC ${store.ruc ?? '-'}',
                ),
                _Line(
                  icon: Icons.location_on_outlined,
                  text: [
                    store.address,
                    store.district,
                  ].whereType<String>().join(', '),
                ),
                _Line(
                  icon: Icons.map_outlined,
                  text: store.hasLocation
                      ? 'Ubicación: ${store.latitude}, ${store.longitude}'
                      : 'Sin ubicación en el mapa',
                ),
                _Line(
                  icon: Icons.phone_outlined,
                  text: store.phone ?? 'Sin teléfono',
                ),
                _Line(
                  icon: Icons.schedule,
                  text: store.openingHours ?? 'Horario no indicado',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Perfil publico: lo que ve el comprador (mapa, calificaciones,
        // comentarios, catalogo). Reusa la ficha del catalogo.
        FilledButton.tonalIcon(
          onPressed: () => Navigator.pushNamed(
            context,
            StorePage.route,
            arguments: store.id,
          ),
          icon: const Icon(Icons.storefront_outlined),
          label: Text('Ver mi perfil público  ·  ${store.ratingLabel}'),
        ),
        const SizedBox(height: 8),
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
              store.paymentConfigured
                  ? Icons.credit_score
                  : Icons.credit_card_off_outlined,
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
                MaterialPageRoute(
                  builder: (_) => PaymentConfigPage(store: store),
                ),
              );
              if (saved == true) onEdited();
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Estados del pedido',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        for (final st in orderTimeline)
          Row(
            children: [
              Icon(orderStatusIcon(st), size: 16, color: orderStatusColor(st)),
              const SizedBox(width: 8),
              Text(
                orderStatusLabel(st),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
      Text(
        label,
        style: const TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      ),
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

// ---------------------------------------------------------------------------
// Chat directo proveedor <-> admin
// ---------------------------------------------------------------------------
class _SupplierDirectChat extends StatefulWidget {
  const _SupplierDirectChat();

  @override
  State<_SupplierDirectChat> createState() => _SupplierDirectChatState();
}

class _SupplierDirectChatState extends State<_SupplierDirectChat> {
  final _messages = <DirectChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _merge(Iterable<DirectChatMessage> news) {
    final ids = {for (final m in _messages) m.id};
    final nuevos = news.where((m) => ids.add(m.id)).toList();
    if (nuevos.isEmpty) return;
    setState(() => _messages.addAll(nuevos));
    _scrollToEnd();
  }

  Future<void> _refresh() async {
    try {
      final news = await AppScope.suppliersOf(context).directMessages(
        afterId: _messages.isEmpty ? 0 : _messages.last.id,
      );
      if (!mounted) return;
      if (_loading) setState(() => _loading = false);
      _merge(news);
    } catch (e) {
      if (mounted && _loading) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _sending = true);
    try {
      final sent = await AppScope.suppliersOf(context).sendDirectMessage(text);
      if (!mounted) return;
      _merge([sent]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final imageUrl = await AppScope.of(context).api.uploadImage(file, folder: 'chat');
      if (!mounted) return;
      final sent = await AppScope.suppliersOf(context)
          .sendDirectMessage('Imagen adjunta', imageUrl: imageUrl);
      if (!mounted) return;
      _merge([sent]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  Widget build(BuildContext context) {
    final me = AppScope.sessionOf(context).user?.id;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Text(
            'Chat directo con el administrador de ChapaTuRepuesto.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const EmptyState(
                      message: 'No hay mensajes aun.\nEscribe al administrador.',
                      icon: Icons.chat_bubble_outline,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final mine = m.senderId == me;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(
                                    m.senderName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (m.imageUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        ApiConfig.imageUrl(m.imageUrl!) ?? m.imageUrl!,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image, size: 48),
                                      ),
                                    ),
                                  ),
                                Text(m.body),
                                Text(
                                  timeLabel(m.at),
                                  style: TextStyle(fontSize: 10, color: scheme.outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _sendImage,
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Enviar imagen',
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje'),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
