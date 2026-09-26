import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/charts.dart';
import '../../orders/domain/order.dart';

/// Estadisticas de la tienda: indicadores, venta por dia, rankings y reparto
/// por estado. Todo sale de `GET /suppliers/stats?days=N`, que ya devuelve la
/// serie con los dias vacios rellenados.
class SupplierStatsView extends StatefulWidget {
  const SupplierStatsView({super.key});

  @override
  State<SupplierStatsView> createState() => _SupplierStatsViewState();
}

class _SupplierStatsViewState extends State<SupplierStatsView> {
  /// Ventanas que el backend acepta (7..180).
  static const _ranges = {7: '7 días', 30: '30 días', 90: '90 días'};

  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return AsyncView<Map<String, dynamic>>(
      refreshKey: _days,
      load: () => scope.suppliers.stats(days: _days),
      builder: (context, data) {
        final totals = (data['totals'] as Map).cast<String, dynamic>();
        final byDay = (data['by_day'] as List).cast<Map<String, dynamic>>();
        final byStatus = (data['by_status'] as Map).cast<String, dynamic>();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _RangePicker(
              ranges: _ranges,
              value: _days,
              onChanged: (d) => setState(() => _days = d),
            ),
            const SizedBox(height: 14),
            _Kpis(totals: totals),
            const SizedBox(height: 18),

            _Panel(
              title: 'Ventas por día',
              subtitle: 'Últimos $_days días · el día más alto va en naranja',
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DailyBars(
                  values: [
                    for (final d in byDay) (d['total'] as num).toDouble(),
                  ],
                  labels: [
                    for (final d in byDay) _shortDay(d['day'] as String),
                  ],
                  formatValue: (v) => soles(v),
                ),
              ),
            ),

            _Panel(
              title: 'Pedidos por día',
              subtitle: 'Cuántas compras entraron cada día',
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DailyBars(
                  height: 110,
                  values: [
                    for (final d in byDay) (d['orders'] as num).toDouble(),
                  ],
                  labels: [
                    for (final d in byDay) _shortDay(d['day'] as String),
                  ],
                  formatValue: (v) => '${v.toInt()} pedido${v == 1 ? '' : 's'}',
                ),
              ),
            ),

            _Panel(
              title: 'Repuestos más vendidos',
              subtitle: 'Por monto facturado en el período',
              child: RankingBars(
                emptyText: 'Todavía no vendiste repuestos en este período.',
                rows: [
                  for (final p
                      in (data['top_products'] as List)
                          .cast<Map<String, dynamic>>())
                    RankingRow(
                      label: p['name'] as String,
                      value: (p['total'] as num).toDouble(),
                      valueText: soles(p['total'] as num),
                      subtitle: [
                        if ((p['brand'] as String).isNotEmpty)
                          p['brand'] as String,
                        '${p['units']} unidad${p['units'] == 1 ? '' : 'es'}',
                      ].join('  ·  '),
                    ),
                ],
              ),
            ),

            _Panel(
              title: 'Ventas por categoría',
              subtitle: 'Dónde está tu fuerte',
              child: RankingBars(
                emptyText: 'Sin ventas por categoría en este período.',
                rows: [
                  for (final c
                      in (data['by_category'] as List)
                          .cast<Map<String, dynamic>>())
                    RankingRow(
                      label: categoryLabel(c['category'] as String),
                      value: (c['total'] as num).toDouble(),
                      valueText: soles(c['total'] as num),
                      subtitle:
                          '${c['units']} unidad${c['units'] == 1 ? '' : 'es'}',
                    ),
                ],
              ),
            ),

            _Panel(
              title: 'Mejores clientes',
              subtitle: 'Talleres y compradores que más te compran',
              child: RankingBars(
                emptyText: 'Aún no tienes clientes en este período.',
                rows: [
                  for (final b
                      in (data['top_buyers'] as List)
                          .cast<Map<String, dynamic>>())
                    RankingRow(
                      label: b['name'] as String,
                      value: (b['total'] as num).toDouble(),
                      valueText: soles(b['total'] as num),
                      subtitle:
                          '${b['orders']} pedido${b['orders'] == 1 ? '' : 's'}',
                    ),
                ],
              ),
            ),

            _Panel(
              title: 'Estado de los pedidos',
              subtitle: 'Todos los pedidos del período, cancelados incluidos',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DonutChart(
                  slices: [
                    for (final status in orderTimeline)
                      DonutSlice(
                        label: orderStatusLabel(status),
                        value: ((byStatus[status] as num?) ?? 0).toDouble(),
                        color: orderStatusColor(status),
                      ),
                    DonutSlice(
                      label: orderStatusLabel('cancelled'),
                      value: ((byStatus['cancelled'] as num?) ?? 0).toDouble(),
                      color: orderStatusColor('cancelled'),
                    ),
                  ],
                ),
              ),
            ),

            _LowStock(
              rows: (data['low_stock'] as List).cast<Map<String, dynamic>>(),
            ),
          ],
        );
      },
    );
  }

  /// "2026-09-25" -> "25/09". El año no aporta nada en una ventana de 90 días.
  static String _shortDay(String iso) =>
      '${iso.substring(8)}/${iso.substring(5, 7)}';
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.ranges,
    required this.value,
    required this.onChanged,
  });

  final Map<int, String> ranges;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        Icon(Icons.insights, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Estadísticas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
    final picker = SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        for (final e in ranges.entries)
          ButtonSegment(value: e.key, label: Text(e.value)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );

    // En celular el titulo y los tres botones no entran en la misma linea
    // (desbordaba 32 px): el selector baja a su propio renglon.
    if (isWide(context)) {
      return Row(
        children: [
          Expanded(child: title),
          picker,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: picker),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.totals});

  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        label: 'Vendido',
        value: soles(totals['revenue'] as num),
        icon: Icons.payments_outlined,
        accent: true,
      ),
      StatTile(
        label: 'Pedidos',
        value: '${totals['orders']}',
        icon: Icons.receipt_long_outlined,
      ),
      StatTile(
        label: 'Unidades',
        value: '${totals['units']}',
        icon: Icons.inventory_2_outlined,
      ),
      StatTile(
        label: 'Ticket promedio',
        value: soles(totals['avg_ticket'] as num),
        icon: Icons.trending_up,
      ),
      StatTile(
        label: 'Clientes',
        value: '${totals['buyers']}',
        icon: Icons.groups_outlined,
      ),
      StatTile(
        label: 'Cancelados',
        value: '${totals['cancelled']}',
        icon: Icons.cancel_outlined,
      ),
      StatTile(
        label: 'Calificación',
        value: (totals['rating_count'] as num) == 0
            ? '—'
            : '${totals['rating_avg']} ★',
        icon: Icons.star_outline,
        hint: '${totals['rating_count']} opiniones',
      ),
    ];

    // Las columnas salen del ancho disponible, no del breakpoint: con 7
    // columnas fijas en escritorio las tarjetas quedaban de 115 px y el
    // contenido se desbordaba por abajo.
    return GridView.extent(
      maxCrossAxisExtent: 190,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: tiles,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    ),
  );
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      color: kBrandOrange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: kBrandOrange),
                const SizedBox(width: 8),
                // Expanded: con fuentes grandes el titulo desbordaba la fila.
                Expanded(
                  child: Text(
                    'Repuestos por reponer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Quedan 3 unidades o menos: si se agotan, dejan de aparecer '
              'como disponibles en el catálogo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r['name']}  ·  ${r['part_code']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StockChip(stock: r['stock'] as int, dense: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
