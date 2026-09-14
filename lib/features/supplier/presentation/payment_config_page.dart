import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/domain/store.dart';

/// Afiliación a la pasarela: núcleo del modelo de negocio. Las credenciales se
/// mandan una vez y el backend las guarda cifradas; aquí solo se ve si están
/// configuradas. Cómo obtenerlas: GUIA_INTEGRACIONES_APP.md.
class PaymentConfigPage extends StatefulWidget {
  const PaymentConfigPage({super.key, required this.store});

  final Store store;

  @override
  State<PaymentConfigPage> createState() => _PaymentConfigPageState();
}

class _PaymentConfigPageState extends State<PaymentConfigPage> {
  final _formKey = GlobalKey<FormState>();
  late String _provider = widget.store.paymentProvider ?? 'simulado';
  final _token = TextEditingController();
  final _merchant = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  static const _providers = {
    'simulado': ('Sin pasarela (demo)', 'Los pagos con tarjeta se aprueban al instante. Solo para pruebas.'),
    'mercadopago': ('Mercado Pago', 'Checkout Pro. Necesitas el Access Token de producción de tu cuenta.'),
    'niubiz': ('Niubiz', 'Necesitas el ID de comercio, usuario y clave de API que te entrega Niubiz.'),
  };

  @override
  void dispose() {
    _token.dispose();
    _merchant.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppScope.suppliersOf(context).configurePayment(
        provider: _provider,
        account: switch (_provider) {
          'mercadopago' => _token.text.trim(),
          'niubiz' => '${_merchant.text.trim()}|${_user.text.trim()}|${_pass.text.trim()}',
          _ => null,
        },
      );
      if (!mounted) return;
      showInfo(context, 'Medio de cobro guardado');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medio de cobro')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'El dinero de cada pedido entra directo a tu cuenta de la pasarela. '
              'ChapaTuRepuesto nunca lo toca.',
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: _provider,
              onChanged: (v) => setState(() => _provider = v ?? _provider),
              child: Column(
                children: [
                  for (final e in _providers.entries)
                    RadioListTile<String>(
                      value: e.key,
                      title: Text(e.value.$1),
                      subtitle: Text(e.value.$2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_provider == 'mercadopago')
              TextFormField(
                controller: _token,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Access Token',
                  helperText: 'APP_USR-... (Tus integraciones → Credenciales de producción)',
                ),
                validator: (v) => (v == null || v.trim().length < 20) ? 'Pega el Access Token' : null,
              ),
            if (_provider == 'niubiz') ...[
              TextFormField(
                controller: _merchant,
                decoration: const InputDecoration(labelText: 'ID de comercio (merchantId)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'Usuario API'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Clave API'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
            ],
            if (widget.store.paymentConfigured && _provider == widget.store.paymentProvider)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Ya tienes credenciales guardadas. Solo se reemplazan si guardas nuevas.'),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
