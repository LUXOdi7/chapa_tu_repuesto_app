import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/domain/store.dart';

/// Alta y edicion de la tienda del proveedor (`POST /suppliers/store` sirve
/// para las dos cosas). Sin tienda registrada el proveedor no puede publicar.
class StoreFormPage extends StatefulWidget {
  const StoreFormPage({super.key, this.store, this.onSaved});

  static const route = '/supplier/store';

  final Store? store;

  /// Cuando la pantalla se muestra incrustada (registro obligatorio al entrar
  /// al panel) no hay ruta que cerrar: se avisa por aqui.
  final VoidCallback? onSaved;

  @override
  State<StoreFormPage> createState() => _StoreFormPageState();
}

class _StoreFormPageState extends State<StoreFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.store?.businessName);
  late final _ruc = TextEditingController(text: widget.store?.ruc);
  late final _address = TextEditingController(text: widget.store?.address);
  late final _district = TextEditingController(text: widget.store?.district);
  late final _phone = TextEditingController(text: widget.store?.phone);
  late final _hours = TextEditingController(text: widget.store?.openingHours);

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _ruc.dispose();
    _address.dispose();
    _district.dispose();
    _phone.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppScope.suppliersOf(context).saveStore(
        businessName: _name.text.trim(),
        ruc: _ruc.text.trim(),
        address: _address.text.trim(),
        district: _district.text.trim(),
        phone: _phone.text.trim(),
        openingHours: _hours.text.trim().isEmpty ? null : _hours.text.trim(),
      );
      if (!mounted) return;
      showInfo(context, 'Tienda guardada');
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // 409 = el RUC ya está registrado por otra tienda.
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.store == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Registra tu tienda' : 'Editar tienda'),
        automaticallyImplyLeading: !isNew,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isNew)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Antes de publicar repuestos necesitamos los datos de tu '
                  'negocio. Aparecerán en el catálogo y en las constancias.',
                ),
              ),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Razón social',
                prefixIcon: Icon(Icons.storefront),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ruc,
              keyboardType: TextInputType.number,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: 'RUC',
                prefixIcon: Icon(Icons.badge_outlined),
                counterText: '',
                helperText: 'Exactamente 11 dígitos',
              ),
              // Validacion en el borde: el backend rechaza cualquier otra cosa,
              // mejor decirlo antes de gastar la peticion.
              validator: (v) =>
                  RegExp(r'^\d{11}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'El RUC son 11 dígitos',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 5) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _district,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Distrito',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 6) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hours,
              decoration: const InputDecoration(
                labelText: 'Horario (opcional)',
                prefixIcon: Icon(Icons.schedule),
                hintText: 'Lun-Sab 8:00-19:00',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isNew ? 'Registrar tienda' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
