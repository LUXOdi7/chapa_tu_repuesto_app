import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _merchant = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  static const _providers = {
    'simulado': (
      'Sin pasarela (demo)',
      'Los pagos con tarjeta se aprueban al instante. Solo para pruebas.',
    ),
    'mercadopago': (
      'Mercado Pago',
      'Checkout Pro. Necesitas el Access Token de producción de tu cuenta.',
    ),
    'niubiz': (
      'Niubiz',
      'Necesitas el ID de comercio, usuario y clave de API que te entrega Niubiz.',
    ),
  };

  @override
  void dispose() {
    _merchant.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // MP usa OAuth: el botón _MpConnectButton maneja la conexión directamente
    if (_provider == 'mercadopago') return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppScope.suppliersOf(context).configurePayment(
        provider: _provider,
        account: switch (_provider) {
          'niubiz' =>
            '${_merchant.text.trim()}|${_user.text.trim()}|${_pass.text.trim()}',
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
      body: FormBox(
        child: Form(
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
              if (_provider == 'mercadopago') _MpConnectButton(store: widget.store),
              if (_provider == 'niubiz') ...[
                TextFormField(
                  controller: _merchant,
                  decoration: const InputDecoration(
                    labelText: 'ID de comercio (merchantId)',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: 'Usuario API'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Clave API'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
              ],
              if (_provider != 'mercadopago' &&
                  widget.store.paymentConfigured &&
                  _provider == widget.store.paymentProvider)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Ya tienes credenciales guardadas. Solo se reemplazan si guardas nuevas.',
                  ),
                ),
              if (_provider != 'mercadopago') ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MpConnectButton extends StatefulWidget {
  const _MpConnectButton({required this.store});
  final Store store;

  @override
  State<_MpConnectButton> createState() => _MpConnectButtonState();
}

class _MpConnectButtonState extends State<_MpConnectButton> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final url = await AppScope.suppliersOf(context).mpConnectUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.store.paymentConfigured &&
        widget.store.paymentProvider == 'mercadopago';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (connected)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Cuenta Mercado Pago conectada'),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: _busy ? null : _connect,
          icon: _busy
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.open_in_browser),
          label: Text(connected ? 'Reconectar Mercado Pago' : 'Conectar Mercado Pago'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF009EE3)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Se abrirá el navegador. Inicia sesión con tu cuenta de Mercado Pago y autoriza.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
