import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Graficas del panel: barras por dia, rankings y dona de estados.
///
/// Dibujadas con widgets y un `CustomPainter` de 30 lineas en vez de sumar una
/// libreria de charts: son tres formas, se ven igual en web y Android, y no
/// agregan una dependencia mas que mantener.
/// ponytail: si algun dia hacen falta zoom, tooltips o ejes con escala
/// logaritmica, ahi si toca fl_chart.

/// Serie diaria en barras. Resalta el dia con mas venta y marca los dias en
/// cero (que son informacion, no un hueco).
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.values,
    required this.labels,
    this.height = 150,
    this.formatValue,
  });

  /// Un valor por dia, en orden.
  final List<double> values;

  /// Etiqueta corta del eje (ej. "12/09"), misma longitud que [values].
  final List<String> labels;
  final double height;
  final String Function(double)? formatValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = values.isEmpty ? 0.0 : values.reduce(math.max);
    final best = max > 0 ? values.indexOf(max) : -1;

    return LayoutBuilder(
      builder: (context, box) {
        // Si no caben, la grafica se desliza en vez de encogerse hasta ser
        // ilegible (30 dias en un celular = 8 px por barra).
        const minBar = 22.0;
        final barWidth = math.max(
          minBar,
          box.maxWidth / math.max(values.length, 1),
        );
        final scroll = barWidth * values.length > box.maxWidth + 1;

        final bars = [
          for (var i = 0; i < values.length; i++)
            _Bar(
              fraction: max > 0 ? values[i] / max : 0,
              highlight: i == best,
              label: labels[i],
              tooltip:
                  '${labels[i]}  ·  '
                  '${formatValue?.call(values[i]) ?? values[i].toStringAsFixed(0)}',
              color: scheme.outlineVariant,
            ),
        ];

        final chart = SizedBox(
          height: height,
          width: scroll ? barWidth * values.length : box.maxWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in bars)
                if (scroll)
                  SizedBox(width: barWidth, child: bar)
                else
                  Expanded(child: bar),
            ],
          ),
        );

        if (!scroll) return chart;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // arranca mostrando los dias mas recientes
          child: chart,
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.highlight,
    required this.label,
    required this.tooltip,
    required this.color,
  });

  final double fraction;
  final bool highlight;
  final String label;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: FractionallySizedBox(
              // Un hilo visible en los dias sin ventas: "cero" tambien es dato.
              heightFactor: fraction <= 0 ? 0.015 : math.max(fraction, 0.04),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: fraction <= 0
                      ? color
                      : (highlight ? kBrandOrange : kBrandBlue),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    ),
  );
}

/// Ranking con barra proporcional: top de repuestos, categorias o clientes.
class RankingBars extends StatelessWidget {
  const RankingBars({
    super.key,
    required this.rows,
    this.emptyText = 'Sin datos todavía.',
  });

  final List<RankingRow> rows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyText, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final max = rows.map((r) => r.value).reduce(math.max);

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Medal(position: i),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rows[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rows[i].valueText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kBrandOrange,
                      ),
                    ),
                  ],
                ),
                if (rows[i].subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 30, top: 2),
                    child: Text(
                      rows[i].subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max > 0 ? rows[i].value / max : 0,
                    minHeight: 7,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                    valueColor: AlwaysStoppedAnimation(
                      i == 0 ? kBrandOrange : kBrandBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RankingRow {
  const RankingRow({
    required this.label,
    required this.value,
    required this.valueText,
    this.subtitle,
  });

  final String label;
  final double value;
  final String valueText;
  final String? subtitle;
}

class _Medal extends StatelessWidget {
  const _Medal({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: position == 0
          ? kBrandOrange
          : Theme.of(context).colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '${position + 1}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: position == 0
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Dona de reparto (pedidos por estado) con su leyenda al costado.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 130});

  final List<DonutSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Sin pedidos en el período.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              slices: slices,
              total: total,
              track: Theme.of(context).colorScheme.outlineVariant,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${total.toInt()}',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text('pedidos', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices.where((s) => s.value > 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${s.value.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.track,
  });

  final List<DonutSlice> slices;
  final double total;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(circle, 0, 2 * math.pi, false, paint..color = track);

    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = 2 * math.pi * (s.value / total);
      canvas.drawArc(
        circle,
        start,
        // Hueco de 2 grados entre porciones: se leen como bloques separados.
        math.max(sweep - 0.035, 0.01),
        false,
        paint..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.slices != slices || old.track != track;
}

/// Tarjeta chica de indicador (ventas, pedidos, ticket promedio...).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.accent = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? hint;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? kBrandOrange : Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
            ),
            if (hint != null)
              Text(hint!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
