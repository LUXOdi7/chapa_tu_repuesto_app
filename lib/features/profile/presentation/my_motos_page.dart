import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/presentation/widgets/compatibility_filters.dart';

/// Mis motos: el buscador arranca filtrado por ellas y la ficha avisa
/// "compatible con tu ...". Se eligen con la misma cascada marca/modelo/año
/// del catálogo, así solo se guardan motos para las que hay repuestos.
class MyMotosPage extends StatefulWidget {
  const MyMotosPage({super.key});

  @override
  State<MyMotosPage> createState() => _MyMotosPageState();
}

class _MyMotosPageState extends State<MyMotosPage> {
  String? _type;
  String? _brand;
  String? _model;
  int? _year;
  bool _busy = false;

  Future<void> _add() async {
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await scope.auth.addMoto(
        type: _type!,
        brand: _brand!,
        model: _model!,
        year: _year!,
      );
      await scope.session.refreshMotos();
      if (mounted) showInfo(context, 'Moto guardada');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(int id) async {
    final scope = AppScope.of(context);
    try {
      await scope.auth.deleteMoto(id);
      await scope.session.refreshMotos();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis motos')),
      body: ListenableBuilder(
        listenable: scope.session,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Guarda tus motos y el buscador te mostrará solo repuestos compatibles.',
            ),
            const SizedBox(height: 12),
            CompatibilityFilters(
              repo: scope.catalog,
              onChanged: (t, b, m, y) => setState(() {
                _type = t;
                _brand = b;
                _model = m;
                _year = y;
              }),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  _busy ||
                      _type == null ||
                      _brand == null ||
                      _model == null ||
                      _year == null
                  ? null
                  : _add,
              icon: const Icon(Icons.add),
              label: const Text('Agregar esta moto'),
            ),
            const SectionTitle('Guardadas'),
            if (scope.session.motos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavía no guardaste ninguna moto.'),
              ),
            for (final moto in scope.session.motos)
              ListTile(
                leading: Icon(motoTypeIcons[moto.type] ?? Icons.two_wheeler),
                title: Text(moto.label),
                subtitle: Text(motoTypeLabel(moto.type)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(moto.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
