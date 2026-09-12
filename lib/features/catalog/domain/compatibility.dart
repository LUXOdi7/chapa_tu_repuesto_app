/// Compatibilidad de un repuesto con un rango de años de un modelo de moto.
class Compatibility {
  const Compatibility({
    required this.motoBrand,
    required this.motoModel,
    required this.yearFrom,
    required this.yearTo,
  });

  final String motoBrand;
  final String motoModel;
  final int yearFrom;
  final int yearTo;

  String get label => '$motoBrand $motoModel $yearFrom-$yearTo';

  factory Compatibility.fromJson(Map<String, dynamic> json) => Compatibility(
        motoBrand: json['moto_brand'] as String? ?? '',
        motoModel: json['moto_model'] as String? ?? '',
        yearFrom: json['year_from'] as int? ?? 0,
        yearTo: json['year_to'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'moto_brand': motoBrand,
        'moto_model': motoModel,
        'year_from': yearFrom,
        'year_to': yearTo,
      };
}
