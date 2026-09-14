import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app_scope.dart';
import '../../../core/app_theme.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/user.dart';
import 'forgot_password_page.dart';
import 'session.dart';

/// Login y registro en una sola pantalla: los campos extra del registro
/// aparecen y desaparecen, que es mas corto que dos rutas casi identicas.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  bool _obscure = true;
  UserRole _role = UserRole.buyer;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final result = _registering
          ? await scope.auth.register(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              role: _role,
            )
          : await scope.auth.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      await scope.session.start(result);
      // El arbol de main.dart escucha la sesion y cambia solo de pantalla.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Google Sign-In (google_sign_in v7): el `idToken` se manda al backend, que
  /// lo verifica y devuelve el mismo JWT del login normal. Requiere
  /// `GOOGLE_SERVER_CLIENT_ID` (ver GUIA_INTEGRACIONES_APP.md).
  ///
  /// Android: `authenticate()` abre el selector de cuenta. Web: no existe
  /// `authenticate()`; `attemptLightweightAuthentication()` muestra el One Tap
  /// de Google y devuelve null si el usuario lo cierra.
  Future<void> _google() async {
    if (ApiConfig.googleServerClientId.isEmpty) {
      showInfo(context, 'Falta configurar GOOGLE_SERVER_CLIENT_ID (ver guía).');
      return;
    }
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      if (!Session.googleReady) {
        await GoogleSignIn.instance.initialize(
          clientId: kIsWeb ? ApiConfig.googleServerClientId : null,
          serverClientId: ApiConfig.googleServerClientId,
        );
        Session.googleReady = true;
      }
      final account = kIsWeb
          ? await GoogleSignIn.instance.attemptLightweightAuthentication()
          : await GoogleSignIn.instance.authenticate();
      if (account == null) return; // cerro el One Tap
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('Google no devolvio idToken');
      await scope.session.start(await scope.auth.google(idToken, role: _role));
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        showInfo(context, 'Google: ${e.description ?? e.code.name}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: kBrandAmber,
                      child: const Icon(Icons.two_wheeler,
                          size: 38, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    Text('ChapaTuRepuesto',
                        textAlign: TextAlign.center,
                        style: text.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _registering
                          ? 'Crea tu cuenta para comprar o vender repuestos'
                          : 'Ingresa con tu correo',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 24),

                    if (_registering) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre o razón social',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Escribe tu nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Correo no válido'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    if (_registering) ...[
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono (opcional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                    ),

                    if (_registering) ...[
                      const SizedBox(height: 16),
                      Text('¿Cómo vas a usar la app?', style: text.labelLarge),
                      const SizedBox(height: 8),
                      SegmentedButton<UserRole>(
                        showSelectedIcon: false,
                        segments: [
                          for (final role in UserRole.registrable)
                            ButtonSegment(value: role, label: Text(role.label)),
                        ],
                        selected: {_role},
                        onSelectionChanged: (s) =>
                            setState(() => _role = s.first),
                      ),
                      const SizedBox(height: 6),
                      Text(_role.hint, style: text.bodySmall),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering ? 'Crear cuenta' : 'Ingresar'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _google,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continuar con Google'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _registering = !_registering),
                      child: Text(_registering
                          ? 'Ya tengo cuenta, ingresar'
                          : 'No tengo cuenta, registrarme'),
                    ),
                    if (!_registering)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ForgotPasswordPage(
                                        email: _email.text.trim()),
                                  ),
                                ),
                        child: const Text('Olvidé mi contraseña'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
