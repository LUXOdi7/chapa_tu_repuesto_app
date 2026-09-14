import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_scope.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/map_picker_page.dart';
import '../domain/product.dart';
import '../domain/store.dart';
import 'product_detail_page.dart';
import 'widgets/product_card.dart';

/// Abre la ubicacion en la app de mapas del telefono. ponytail: un intent
/// `geo:` / URL de Google Maps en vez de google_maps_flutter + API key; poner
/// el mapa embebido cuando haga falta ver varias tiendas a la vez.
Future<void> openDirections(BuildContext context, Store store) async {
  final uri = store.hasLocation
      ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${store.latitude},${store.longitude}')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${store.address ?? ''} ${store.district ?? ''}')}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    showInfo(context, 'No se pudo abrir el mapa.');
  }
}

Future<void> callStore(BuildContext context, String phone) async {
  if (!await launchUrl(Uri.parse('tel:$phone')) && context.mounted) {
    showInfo(context, 'No se pudo abrir el marcador.');
  }
}

/// Perfil público de una tienda: datos, calificaciones y su catálogo.
class StorePage extends StatelessWidget {
  const StorePage({super.key, required this.storeId});

  static const route = '/store';

  final int storeId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tienda')),
      body: AsyncView<Store>(
        load: () => scope.catalog.store(storeId),
        builder: (context, store) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Header(store: store),
            if (store.hasLocation)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: StoreMap(point: LatLng(store.latitude!, store.longitude!)),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => openDirections(context, store),
                      icon: const Icon(Icons.directions),
                      label: const Text('Cómo llegar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (store.phone != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => callStore(context, store.phone!),
                        icon: const Icon(Icons.call),
                        label: const Text('Llamar'),
                      ),
                    ),
                ],
              ),
            ),
            if (store.description != null && store.description!.isNotEmpty) ...[
              const SectionTitle('Sobre la tienda'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(store.description!)),
            ],
            const SectionTitle('Calificaciones'),
            AsyncView<List<StoreReview>>(
              load: () => scope.catalog.storeReviews(storeId),
              isEmpty: (r) => r.isEmpty,
              emptyIcon: Icons.star_border,
              emptyMessage: 'Todavía no tiene calificaciones.',
              builder: (context, reviews) => Column(
                children: [
                  for (final r in reviews.take(5))
                    ListTile(
                      dense: true,
                      leading: Text('${r.rating} ★', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      title: Text(r.comment.isEmpty ? 'Sin comentario' : r.comment),
                      subtitle: Text(r.buyerName),
                    ),
                ],
              ),
            ),
            SectionTitle('Repuestos (${store.productCount ?? 0})'),
            AsyncView<ProductPage>(
              load: () => scope.catalog.products(storeId: storeId, limit: 60),
              isEmpty: (p) => p.items.isEmpty,
              emptyMessage: 'Esta tienda aún no publicó repuestos.',
              builder: (context, page) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 250,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: page.items.length,
                itemBuilder: (context, i) {
                  final product = page.items[i];
                  return ProductCard(
                    product: product,
                    compatibilityConfirmed: false,
                    onTap: () => Navigator.pushNamed(context, ProductDetailPage.route, arguments: product.id),
                    onAdd: () {
                      scope.cart.add(product);
                      showInfo(context, '${product.name} agregado');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logo = ApiConfig.imageUrl(store.logoUrl);
    return Container(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.surface,
            backgroundImage: logo != null ? NetworkImage(logo) : null,
            child: logo == null ? const Icon(Icons.storefront, size: 32) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(store.businessName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer)),
                    ),
                    if (store.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_user, size: 18, color: Colors.blue),
                    ],
                  ],
                ),
                Text(store.ratingLabel, style: TextStyle(color: scheme.onPrimaryContainer)),
                Text([store.address, store.district].whereType<String>().join(', '),
                    style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 13)),
                if (store.openingHours != null)
                  Text(store.openingHours!,
                      style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Directorio de tiendas (pestaña "Tiendas" del comprador).
class StoresView extends StatefulWidget {
  const StoresView({super.key});

  @override
  State<StoresView> createState() => _StoresViewState();
}

class _StoresViewState extends State<StoresView> {
  String _q = '';
  bool _onlyVerified = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Buscar tienda', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('Solo tiendas verificadas'),
          value: _onlyVerified,
          onChanged: (v) => setState(() => _onlyVerified = v),
        ),
        Expanded(
          child: AsyncView<List<Store>>(
            refreshKey: '$_q|$_onlyVerified',
            load: () => scope.catalog.stores(q: _q.isEmpty ? null : _q, onlyVerified: _onlyVerified),
            isEmpty: (s) => s.isEmpty,
            emptyIcon: Icons.storefront_outlined,
            emptyMessage: 'No encontramos tiendas.',
            builder: (context, stores) => ListView.separated(
              itemCount: stores.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = stores[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.storefront)),
                  title: Row(
                    children: [
                      Flexible(child: Text(s.businessName, overflow: TextOverflow.ellipsis)),
                      if (s.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_user, size: 14, color: Colors.blue),
                      ],
                    ],
                  ),
                  subtitle: Text([s.district, s.distanceLabel, s.ratingLabel]
                      .whereType<String>()
                      .where((t) => t.isNotEmpty)
                      .join('  ·  ')),
                  trailing: IconButton(
                    tooltip: 'Cómo llegar',
                    icon: const Icon(Icons.directions),
                    onPressed: () => openDirections(context, s),
                  ),
                  onTap: () => Navigator.pushNamed(context, StorePage.route, arguments: s.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
