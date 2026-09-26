import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../shared/widgets/app_widgets.dart';

/// Recuperación en dos pasos: pedir el código al correo y luego escribir
/// código + nueva contraseña. Si el código es válido la sesión queda iniciada.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      if (!_sent) {
        await scope.auth.forgot(_email.text.trim());
        if (mounted) {
          setState(() => _sent = true);
          showInfo(
            context,
            'Si el correo existe, te enviamos un código de 6 dígitos.',
          );
        }
      } else {
        final result = await scope.auth.reset(
          email: _email.text.trim(),
          code: _code.text.trim(),
          password: _password.text,
        );
        await scope.session.start(result);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _sent
                  ? 'Escribe el código que llegó a tu correo y tu nueva contraseña.'
                  : 'Te enviaremos un código a tu correo para crear una contraseña nueva.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              enabled: !_sent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo no válido' : null,
            ),
            if (_sent) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de 6 dígitos',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Son 6 dígitos',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_sent ? 'Cambiar contraseña' : 'Enviar código'),
            ),
            if (_sent)
              TextButton(
                onPressed: _busy ? null : () => setState(() => _sent = false),
                child: const Text('Volver a enviar el código'),
              ),
          ],
        ),
      ),
    );
  }
}
