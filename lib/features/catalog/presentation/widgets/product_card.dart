import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/product.dart';

/// Tarjeta de la grilla de resultados.
/// Muestra lo unico que decide una compra en el taller: precio, stock, tienda
/// y si calza en la moto filtrada.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAdd,
    this.compatibilityConfirmed = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  /// True cuando hay moto seleccionada en los filtros: el backend ya devolvio
  /// solo piezas compatibles, asi que el sello es informativo.
  final bool compatibilityConfirmed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final store = product.store;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PartImage(path: product.imageUrl, height: 92),
                Positioned(
                  top: 6,
                  left: 6,
                  child: StockChip(stock: product.stock, dense: true),
                ),
                if (compatibilityConfirmed)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Tooltip(
                      message: 'Compatibilidad garantizada',
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.green,
                        child: const Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Marca + codigo: es lo que el mecanico compara entre tiendas.
                    Text(
                      product.brandAndCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (store != null)
                      Row(
                        children: [
                          Icon(
                            Icons.storefront,
                            size: 12,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${store.businessName}  ${store.distanceLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            soles(product.price),
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: product.inStock
                              ? 'Agregar al carrito'
                              : 'Sin stock',
                          onPressed: product.inStock ? onAdd : null,
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
