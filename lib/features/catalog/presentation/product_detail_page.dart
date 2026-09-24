import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/product.dart';
import '../../auth/domain/user.dart';
import '../../profile/presentation/alerts_page.dart';
import 'store_page.dart';

/// Ficha del repuesto + comparador de ofertas.
///
/// `offers` viene del backend con la MISMA pieza (mismo `part_code`) en otras
/// tiendas, ya ordenada por precio y luego por distancia. Tocar una oferta
/// cambia la tienda seleccionada; el boton de agregar usa siempre la elegida.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  static const route = '/product';

  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  /// Oferta elegida dentro del comparador; null = la pieza que se abrio.
  Product? _picked;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del repuesto')),
      body: AsyncView<Product>(
        load: () => scope.catalog.product(widget.productId),
        builder: (context, detail) {
          final selected = _picked ?? detail;
          // "Mis motos" que encajan en alguna compatibilidad declarada.
          final myMotos = scope.session.motos
              .where((m) => detail.compatibilities.any((c) =>
                  c.motoBrand == m.brand &&
                  c.motoModel == m.model &&
                  m.year >= c.yearFrom &&
                  m.year <= c.yearTo))
              .toList();
          // El propio producto tambien es una oferta: si el backend no lo
          // incluye en la lista, se antepone para poder volver a elegirlo.
          final offers = [
            if (!detail.offers.any((o) => o.id == detail.id)) detail,
            ...detail.offers,
          ];
          return _Detail(
            detail: detail,
            selected: selected,
            offers: offers,
            myMotos: myMotos,
            onPick: (p) => setState(() => _picked = p),
            onAdd: () {
              scope.cart.add(selected);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.detail,
    required this.selected,
    required this.offers,
    required this.myMotos,
    required this.onPick,
    required this.onAdd,
  });

  final Product detail;
  final Product selected;
  final List<Product> offers;
  final List<UserMoto> myMotos;
  final ValueChanged<Product> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final store = selected.store;
    final cheapest = offers.isEmpty
        ? selected.price
        : offers.map((o) => o.price).reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Gallery(images: selected.imageUrls.isEmpty ? detail.imageUrls : selected.imageUrls),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.name, style: text.headlineSmall),
                    if (myMotos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, size: 18, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Compatible con tu ${myMotos.map((m) => '${m.brand} ${m.model}').join(' y tu ')}',
                                style: text.bodyMedium?.copyWith(
                                    color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(categoryLabel(detail.category)),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (detail.brand != null)
                          Chip(
                            label: Text(detail.brand!),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(detail.partCode),
                          visualDensity: VisualDensity.compact,
                        ),
                        StockChip(stock: selected.stock),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          soles(selected.price),
                          style: text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        const Spacer(),
                        if (store != null)
                          Flexible(
                            child: InkWell(
                              onTap: () => Navigator.pushNamed(
                                  context, StorePage.route, arguments: store.id),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.storefront, size: 16, color: scheme.outline),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${store.businessName}  ${store.distanceLabel}',
                                      style: text.bodySmall?.copyWith(
                                          decoration: TextDecoration.underline),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (selected.warrantyMonths != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 16, color: scheme.outline),
                          const SizedBox(width: 4),
                          Text('Garantía ${selected.warrantyMonths} meses',
                              style: text.bodySmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (detail.description != null &&
                  detail.description!.isNotEmpty) ...[
                const SectionTitle('Descripción'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(detail.description!),
                ),
              ],
              const SectionTitle('Compatibilidad comprobada'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: detail.compatibilities.isEmpty
                    ? const Text('El proveedor no cargó compatibilidades.')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in detail.compatibilities)
                            Chip(
                              avatar: Icon(motoTypeIcons[c.motoType] ?? Icons.verified,
                                  size: 16, color: Colors.green),
                              label: Text(c.fullLabel),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
              ),
              SectionTitle('Ofertas (${offers.length})'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Ordenadas por precio y luego por cercanía. Toca una para '
                  'comprarle a esa tienda.',
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
              for (final offer in offers)
                _OfferTile(
                  product: offer,
                  selected: offer.id == selected.id,
                  cheapest: offer.price == cheapest,
                  onTap: () => onPick(offer),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Alerta de stock/precio para este codigo de parte.
                IconButton.outlined(
                  tooltip: 'Avísame cuando haya stock o baje de precio',
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => showCreateAlertDialog(context,
                      partCode: detail.partCode, price: selected.price),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(selected.inStock
                        ? 'Agregar  ${soles(selected.price)}'
                        : 'Sin stock en esta tienda'),
                    onPressed: selected.inStock ? onAdd : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.product,
    required this.selected,
    required this.cheapest,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final bool cheapest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = product.store;

    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: 0.08),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: const Icon(Icons.storefront, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(store?.businessName ?? 'Tienda',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (store?.verified ?? false) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified_user, size: 14, color: Colors.blue),
          ],
        ],
      ),
      subtitle: Text(
        [
          store?.district,
          store?.distanceLabel,
          store?.ratingLabel,
        ].whereType<String>().where((s) => s.isNotEmpty).join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(soles(product.price),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cheapest ? Colors.green : scheme.onSurface,
              )),
          StockChip(stock: product.stock, dense: true),
        ],
      ),
    );
  }
}

/// Carrusel de fotos con puntos; una sola foto = imagen fija.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.length <= 1) {
      return PartImage(path: widget.images.isEmpty ? null : widget.images.first, height: 220);
    }
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => PartImage(path: widget.images[i], height: 220),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.images.length; i++)
                  Container(
                    width: i == _page ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page ? Theme.of(context).colorScheme.secondary : Colors.white70,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
