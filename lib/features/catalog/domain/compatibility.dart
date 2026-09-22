import '../../../core/format.dart';

/// Compatibilidad de un repuesto con un rango de años de un modelo de moto.
/// `motoType`: lineal (2 ruedas), carguero (tolva) o mototaxi (cabina).
class Compatibility {
  const Compatibility({
    required this.motoBrand,
    required this.motoModel,
    required this.yearFrom,
    required this.yearTo,
    this.motoType = 'lineal',
  });

  final String motoType;
  final String motoBrand;
  final String motoModel;
  final int yearFrom;
  final int yearTo;

  String get label => '$motoBrand $motoModel $yearFrom-$yearTo';

  /// "Mototaxi · Bajaj RE 4S Torito 2012-2025"
  String get fullLabel => '${motoTypeLabel(motoType)} · $label';

  factory Compatibility.fromJson(Map<String, dynamic> json) => Compatibility(
    motoType: json['moto_type'] as String? ?? 'lineal',
    motoBrand: json['moto_brand'] as String? ?? '',
    motoModel: json['moto_model'] as String? ?? '',
    yearFrom: json['year_from'] as int? ?? 0,
    yearTo: json['year_to'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'moto_type': motoType,
    'moto_brand': motoBrand,
    'moto_model': motoModel,
    'year_from': yearFrom,
    'year_to': yearTo,
  };
}
