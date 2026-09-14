import 'package:flutter/material.dart';

import '../../data/catalog_repository.dart';

/// Filtros en cascada Marca -> Modelo -> Año, alimentados por
/// `/catalog/moto-brands`, `/catalog/moto-models` y `/catalog/moto-years`.
///
/// Cada nivel se habilita solo cuando el anterior tiene valor y se limpia hacia
/// abajo al cambiar: es lo que evita combinaciones imposibles (un año que ese
/// modelo nunca tuvo).
class CompatibilityFilters extends StatefulWidget {
  const CompatibilityFilters({
    super.key,
    required this.repo,
    required this.onChanged,
  });

  final CatalogRepository repo;

  /// Devuelve la seleccion completa ya normalizada (nulls incluidos).
  final void Function(String? motoBrand, String? motoModel, int? year) onChanged;

  @override
  State<CompatibilityFilters> createState() => CompatibilityFiltersState();
}

class CompatibilityFiltersState extends State<CompatibilityFilters> {
  List<String> _brands = const [];
  List<String> _models = const [];
  List<int> _years = const [];

  String? _brand;
  String? _model;
  int? _year;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  /// Si el catalogo no responde, los desplegables quedan vacios (inertes) y el
  /// error se ve en la zona de resultados: no tiene sentido gritarlo dos veces.
  Future<void> _loadBrands() async {
    try {
      final brands = await widget.repo.motoBrands();
      if (mounted) setState(() => _brands = brands);
    } catch (_) {
      /* silencioso a proposito */
    }
  }

  Future<void> _pickBrand(String? brand) async {
    setState(() {
      _brand = brand;
      _model = null;
      _year = null;
      _models = const [];
      _years = const [];
    });
    widget.onChanged(_brand, null, null);
    if (brand == null) return;
    try {
      final models = await widget.repo.motoModels(brand);
      if (mounted && _brand == brand) setState(() => _models = models);
    } catch (_) {/* silencioso a proposito */}
  }

  Future<void> _pickModel(String? model) async {
    setState(() {
      _model = model;
      _year = null;
      _years = const [];
    });
    widget.onChanged(_brand, _model, null);
    if (model == null || _brand == null) return;
    try {
      final years = await widget.repo.motoYears(_brand!, model);
      if (mounted && _model == model) setState(() => _years = years);
    } catch (_) {/* silencioso a proposito */}
  }

  void _pickYear(int? year) {
    setState(() => _year = year);
    widget.onChanged(_brand, _model, _year);
  }

  /// La usa la pantalla desde el boton "Quitar moto".
  void clear() => _pickBrand(null);

  /// Selecciona una moto guardada ("Mis motos"): carga cada nivel de la
  /// cascada y deja los desplegables coherentes con lo elegido.
  Future<void> select(String brand, String model, int year) async {
    await _pickBrand(brand);
    await _pickModel(model);
    _pickYear(year);
  }

  bool get hasMoto => _brand != null;

  String get motoLabel =>
      [_brand, _model, _year?.toString()].whereType<String>().join(' ');

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _Dropdown<String>(
              label: 'Marca',
              value: _brand,
              items: _brands,
              onChanged: _pickBrand,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Dropdown<String>(
              label: 'Modelo',
              value: _model,
              items: _models,
              onChanged: _pickModel,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: _Dropdown<int>(
              label: 'Año',
              value: _year,
              items: _years,
              onChanged: _pickYear,
            ),
          ),
        ],
      );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // La key fuerza el reset del FormField cuando la cascada limpia niveles
      // inferiores; sin ella el desplegable conserva la seleccion anterior.
      key: ValueKey('$label|$value|${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      hint: Text(label, overflow: TextOverflow.ellipsis),
      // Sin items el desplegable queda inerte: asi se ve la cascada.
      onChanged: items.isEmpty ? null : onChanged,
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text('Todas',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ),
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text('$item', overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}
