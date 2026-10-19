import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/user.dart';
import 'forgot_password_page.dart';
import 'google/google_button.dart';
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

  /// Web: el boton lo dibuja Google y el resultado llega por este stream.
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;
  bool _googleInit = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _initGoogleWeb();
  }

  /// El client ID puede llegar del backend (/health) un instante despues de
  /// arrancar: se espera hasta 5 s antes de inicializar y dibujar el boton.
  Future<void> _initGoogleWeb() async {
    for (var i = 0; i < 20 && ApiConfig.googleClientId.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final clientId = ApiConfig.googleClientId;
    if (clientId.isEmpty || !mounted) return;
    try {
      if (!Session.googleReady) {
        await GoogleSignIn.instance.initialize(clientId: clientId);
        Session.googleReady = true;
      }
      _googleEvents = GoogleSignIn.instance.authenticationEvents.listen((
        event,
      ) async {
        if (event is! GoogleSignInAuthenticationEventSignIn || !mounted) return;
        final idToken = event.user.authentication.idToken;
        if (idToken == null) {
          showInfo(context, 'Google no devolvió idToken');
          return;
        }
        final scope = AppScope.of(context);
        setState(() => _busy = true);
        try {
          await scope.session.start(
            await scope.auth.google(idToken, role: _role),
          );
        } catch (e) {
          if (mounted) showError(context, e);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      });
      if (mounted) setState(() => _googleInit = true);
    } catch (e) {
      if (mounted) showInfo(context, 'Google: $e');
    }
  }

  @override
  void dispose() {
    _googleEvents?.cancel();
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
    final clientId = ApiConfig.googleClientId;
    if (clientId.isEmpty) {
      showInfo(
        context,
        'Google no está configurado: pon GOOGLE_CLIENT_ID en el .env del backend '
        '(o compila con --dart-define=GOOGLE_SERVER_CLIENT_ID). Ver INSTALACION.md §4.',
      );
      return;
    }
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      if (!Session.googleReady) {
        // Web: solo `clientId` (el plugin web rechaza serverClientId).
        // Android: solo `serverClientId` (necesario para recibir el idToken).
        await GoogleSignIn.instance.initialize(
          clientId: kIsWeb ? clientId : null,
          serverClientId: kIsWeb ? null : clientId,
        );
        Session.googleReady = true;
      }
      final account = kIsWeb
          ? await GoogleSignIn.instance.attemptLightweightAuthentication()
          : await GoogleSignIn.instance.authenticate();
      if (account == null) {
        // En web el One Tap no aparece si el origen (http://localhost:5000) no
        // esta autorizado en el cliente web, si el usuario lo cerro varias
        // veces (Google lo silencia un rato) o si no hay sesion de Google en
        // el navegador.
        if (mounted && kIsWeb) {
          showInfo(
            context,
            'Google no mostró el inicio de sesión. Revisa la consola del '
            'navegador (F12) y que http://localhost:5000 esté en "Orígenes autorizados".',
          );
        }
        return;
      }
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('Google no devolvió idToken');
      await scope.session.start(await scope.auth.google(idToken, role: _role));
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        showInfo(context, 'Google: ${e.description ?? e.code.name}');
      }
    } on ApiException catch (e) {
      if (mounted) showError(context, e); // 401/501 del backend, ya redactado
    } catch (e) {
      // Errores del plugin/navegador: mostrar el texto real, no "inesperado".
      if (mounted) showInfo(context, 'Google: $e');
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
                    const BrandLogo(height: 170),
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
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
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
                    // Web: boton oficial de Google (popup). Android: el nuestro
                    // abre el selector de cuenta nativo.
                    if (kIsWeb && _googleInit)
                      Center(child: googleWebButton())
                    else
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _google,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(
                          kIsWeb
                              ? 'Cargando Google...'
                              : 'Continuar con Google',
                        ),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _registering = !_registering),
                      child: Text(
                        _registering
                            ? 'Ya tengo cuenta, ingresar'
                            : 'No tengo cuenta, registrarme',
                      ),
                    ),
                    if (!_registering)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ForgotPasswordPage(
                                    email: _email.text.trim(),
                                  ),
                                ),
                              ),
                        child: const Text('Olvidé mi contraseña'),
                      ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(
                            'https://github.com/LUXOdi7/chapa_tu_repuesto_app'
                            '/releases/latest/download/app-release.apk',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.android),
                        label: const Text('Descargar app para Android'),
                      ),
                    ],
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
