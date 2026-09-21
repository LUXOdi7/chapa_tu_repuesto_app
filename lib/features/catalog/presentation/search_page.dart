import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/product.dart';
import 'product_detail_page.dart';
import 'widgets/compatibility_filters.dart';
import 'widgets/product_card.dart';
import 'widgets/voice_search_bar.dart';

/// Pantalla principal del comprador: busqueda por texto o dictado, filtros de
/// compatibilidad en cascada y grilla de resultados del backend.
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _controller = TextEditingController();
  final _filtersKey = GlobalKey<CompatibilityFiltersState>();

  String _query = '';
  String? _motoBrand;
  String? _motoModel;
  int? _year;
  String? _category;
  bool _onlyInStock = false;
  String _orderBy = 'relevance';

  /// Paginas extra cargadas con "Ver mas". Se acumulan sin tocar el
  /// `AsyncView` (que solo pide la primera pagina), asi la grilla no se
  /// reconstruye ni pierde el scroll. `_extraFor` recuerda para que busqueda
  /// valen: si cambia la busqueda, se descartan.
  final List<Product> _extra = [];
  String _extraFor = '';
  bool _loadingMore = false;
  static const _pageSize = 20;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Sin debounce cada tecla dispararia una peticion al catalogo.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _reset() {
    setState(() {
      _category = null;
      _onlyInStock = false;
      _orderBy = 'relevance';
    });
    _filtersKey.currentState?.clear();
  }

  bool get _hasMoto => _motoBrand != null;

  String get _motoLabel =>
      [_motoBrand, _motoModel, _year?.toString()].whereType<String>().join(' ');

  /// Si la moto activa es una de "Mis motos", el encabezado lo dice.
  bool _isMyMoto(BuildContext context) => AppScope.sessionOf(context).motos.any(
      (m) => m.brand == _motoBrand && m.model == _motoModel && m.year == _year);

  /// Cualquier cambio de esta cadena recarga el `AsyncView`.
  String get _searchKey =>
      '$_query|$_motoBrand|$_motoModel|$_year|$_category|$_onlyInStock|$_orderBy';

  List<Product> get _extraItems => _extraFor == _searchKey ? _extra : const [];

  Future<void> _loadMore(int offset) async {
    if (_loadingMore) return;
    final key = _searchKey;
    setState(() => _loadingMore = true);
    try {
      final page = await AppScope.catalogOf(context).products(
        q: _query.isEmpty ? null : _query,
        category: _category,
        motoBrand: _motoBrand,
        motoModel: _motoModel,
        year: _year,
        onlyInStock: _onlyInStock ? true : null,
        orderBy: _orderBy,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || key != _searchKey) return;
      setState(() {
        if (_extraFor != key) _extra.clear();
        _extraFor = key;
        _extra.addAll(page.items);
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              VoiceSearchBar(
                controller: _controller,
                onChanged: _onQueryChanged,
              ),
              const SizedBox(height: 12),
              CompatibilityFilters(
                key: _filtersKey,
                repo: scope.catalog,
                onChanged: (brand, model, year) => setState(() {
                  _motoBrand = brand;
                  _motoModel = model;
                  _year = year;
                }),
              ),
            ],
          ),
        ),
        // Mis motos: un toque y el catalogo queda filtrado por esa moto.
        ListenableBuilder(
          listenable: scope.session,
          builder: (context, _) => scope.session.motos.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    children: [
                      for (final moto in scope.session.motos) ...[
                        ChoiceChip(
                          avatar: const Icon(Icons.two_wheeler, size: 16),
                          label: Text(moto.label),
                          selected: _motoBrand == moto.brand &&
                              _motoModel == moto.model &&
                              _year == moto.year,
                          visualDensity: VisualDensity.compact,
                          onSelected: (on) => on
                              ? _filtersKey.currentState
                                  ?.select(moto.brand, moto.model, moto.year)
                              : _filtersKey.currentState?.clear(),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
        ),
        _FilterChips(
          category: _category,
          onlyInStock: _onlyInStock,
          orderBy: _orderBy,
          onCategory: (c) => setState(() => _category = c),
          onStock: (v) => setState(() => _onlyInStock = v),
          onOrder: (o) => setState(() => _orderBy = o),
        ),
        Expanded(
          child: AsyncView<ProductPage>(
            refreshKey: _searchKey,
            load: () => scope.catalog.products(
              q: _query.isEmpty ? null : _query,
              category: _category,
              motoBrand: _motoBrand,
              motoModel: _motoModel,
              year: _year,
              onlyInStock: _onlyInStock ? true : null,
              orderBy: _orderBy,
              limit: _pageSize,
            ),
            isEmpty: (page) => page.items.isEmpty,
            emptyIcon: Icons.search_off,
            emptyMessage: _hasMoto
                ? 'No encontramos repuestos para esa moto.\n'
                    'Prueba quitando el año o el modelo.'
                : 'No encontramos repuestos para esa búsqueda.\n'
                    'Prueba con el código de parte.',
            builder: (context, page) {
              final items = [...page.items, ..._extraItems];
              final remaining = page.total - items.length;
              return Column(
              children: [
                _ResultsHeader(
                  count: page.total,
                  moto: _hasMoto
                      ? (_isMyMoto(context) ? 'tu $_motoLabel' : _motoLabel)
                      : null,
                  onClear: _hasMoto || _category != null || _onlyInStock
                      ? _reset
                      : null,
                ),
                // Lo que se entendio de la oracion dictada/escrita.
                if (page.parsedChips.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const Center(child: Text('Entendí: ')),
                        for (final chip in page.parsedChips) ...[
                          Chip(
                            label: Text(chip),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                Expanded(
                  // Android entrega un primer frame de ancho 0 al arrancar en
                  // frio y `SliverGridDelegateWithMaxCrossAxisExtent` asserta
                  // con crossAxisExtent == 0 (pantalla negra). Saltamos ese
                  // frame.
                  child: LayoutBuilder(
                    builder: (context, constraints) => constraints.maxWidth <= 0
                        ? const SizedBox.shrink()
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisExtent: 250,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            // Ultima celda: boton "Ver mas" (no se reinicia la
                            // grilla; los nuevos se agregan debajo).
                            itemCount: items.length + (remaining > 0 ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == items.length) {
                                return Center(
                                  child: _loadingMore
                                      ? const CircularProgressIndicator()
                                      : FilledButton.tonalIcon(
                                          onPressed: () => _loadMore(items.length),
                                          icon: const Icon(Icons.expand_more),
                                          label: Text('Ver más\n($remaining restantes)',
                                              textAlign: TextAlign.center),
                                          style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 48)),
                                        ),
                                );
                              }
                              final product = items[i];
                              return ProductCard(
                                product: product,
                                compatibilityConfirmed: _hasMoto,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  ProductDetailPage.route,
                                  arguments: product.id,
                                ),
                                onAdd: () {
                                  scope.cart.add(product);
                                  showInfo(context, '${product.name} agregado');
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.category,
    required this.onlyInStock,
    required this.orderBy,
    required this.onCategory,
    required this.onStock,
    required this.onOrder,
  });

  final String? category;
  final bool onlyInStock;
  final String orderBy;
  final ValueChanged<String?> onCategory;
  final ValueChanged<bool> onStock;
  final ValueChanged<String> onOrder;

  static const _orders = {
    'relevance': 'Relevancia',
    'price': 'Menor precio',
    'price_desc': 'Mayor precio',
    'rating': 'Mejor calificados',
  };

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            FilterChip(
              label: const Text('Con stock'),
              selected: onlyInStock,
              onSelected: onStock,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              initialValue: orderBy,
              onSelected: onOrder,
              itemBuilder: (_) => [
                for (final entry in _orders.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort, size: 16),
                label: Text(_orders[orderBy] ?? 'Orden'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            for (final key in knownCategories) ...[
              FilterChip(
                label: Text(categoryLabel(key)),
                selected: category == key,
                onSelected: (on) => onCategory(on ? key : null),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.moto,
    required this.onClear,
  });

  final int count;
  final String? moto;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              moto != null
                  ? '$count repuestos compatibles con $moto'
                  : '$count repuestos encontrados',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Limpiar'),
              style: TextButton.styleFrom(foregroundColor: scheme.outline),
            ),
        ],
      ),
    );
  }
}
