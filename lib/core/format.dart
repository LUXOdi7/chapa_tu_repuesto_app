/// Formato de moneda (Soles) con separador de miles: "S/ 1,234.50".
///
/// ponytail: son 3 lineas contra una dependencia entera (`intl`); cambiar a
/// `NumberFormat.currency` el dia que haya multi-moneda o localizacion real.
String soles(num value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts[0].replaceAll('-', '');
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return 'S/ ${value < 0 ? '-' : ''}$grouped.${parts[1]}';
}

/// El backend manda ISO 8601 **sin zona horaria y en UTC**. `DateTime.parse`
/// interpretaria esos numeros como hora local, asi que hay que marcarlos como
/// UTC antes de convertir; si no, el pedido aparece con 5 horas de diferencia.
DateTime parseServerDate(String value) {
  final hasZone =
      value.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value);
  return DateTime.parse(hasZone ? value : '${value}Z').toLocal();
}

DateTime? parseServerDateOrNull(String? value) =>
    (value == null || value.isEmpty) ? null : parseServerDate(value);

String _two(int n) => n.toString().padLeft(2, '0');

/// "08/09/2026"
String shortDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// "08/09/2026 19:35"
String dateTimeLabel(DateTime d) =>
    '${shortDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

/// Las categorias llegan del backend en minuscula y en ingles/sin tildes
/// (`frenos`, `electrico`, `transmision`): la UI nunca las muestra crudas.
const _categoryLabels = <String, String>{
  'motor': 'Motor',
  'frenos': 'Frenos',
  'transmision': 'Transmisión',
  'electrico': 'Eléctrico',
  'carroceria': 'Carrocería',
  'llantas': 'Llantas',
  'lubricantes': 'Lubricantes',
};

/// Traduce la categoria; si el backend agrega una nueva, la capitaliza en vez
/// de mostrar un hueco.
String categoryLabel(String key) =>
    _categoryLabels[key] ??
    (key.isEmpty ? key : key[0].toUpperCase() + key.substring(1));

List<String> get knownCategories => _categoryLabels.keys.toList();
