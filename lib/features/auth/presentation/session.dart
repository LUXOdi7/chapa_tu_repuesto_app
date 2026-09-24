import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Sesion del usuario: token en almacenamiento seguro + perfil en memoria.
///
/// Es la unica pieza que escribe `ApiClient.token`, y la que reacciona al 401
/// del interceptor cerrando la sesion (la app vuelve sola al login).
class Session extends ChangeNotifier {
  Session(this._api, this._auth) {
    _api.onUnauthorized = () => unawaited(signOut());
  }

  static const _tokenKey = 'ctr_jwt';

  final ApiClient _api;
  final AuthRepository _auth;
  final _storage = const FlutterSecureStorage();

  User? _user;
  bool _restoring = true;

  /// Motos del comprador; se cargan al iniciar sesion y se usan en el
  /// buscador (arranca filtrado) y en la ficha ("compatible con tu ...").
  List<UserMoto> motos = const [];

  User? get user => _user;
  bool get restoring => _restoring;
  bool get isSignedIn => _user != null;

  /// Al abrir la app: si hay token guardado se valida contra `/auth/me`. Si el
  /// backend lo rechaza (o no responde), se borra y se pide login otra vez.
  Future<void> restore() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      _api.token = token;
      try {
        _user = await _auth.me();
        await refreshMotos();
        await registerFcmToken();
      } catch (_) {
        _api.token = null;
        await _storage.delete(key: _tokenKey);
      }
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> start(AuthResult result) async {
    _api.token = result.token;
    _user = result.user;
    await _storage.write(key: _tokenKey, value: result.token);
    notifyListeners();
    await refreshMotos();
    await registerFcmToken();
  }

  Future<void> registerFcmToken() async {
  if (kIsWeb || Firebase.apps.isEmpty || _user == null) return;

  try {
    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();

    if (token != null && token.isNotEmpty) {
      await _auth.registerDeviceToken(token);
    }
  } catch (_) {
    // Las notificaciones no deben impedir el inicio de sesión.
  }
}

  Future<void> refreshMotos() async {
    if (_user == null || _user!.isAdmin) return;
    try {
      motos = await _auth.motos();
    } catch (_) {
      motos = const [];
    }
    notifyListeners();
  }

  /// Tras editar el perfil (`PATCH /auth/me`).
  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }

  /// Lo pone LoginPage tras `GoogleSignIn.instance.initialize`. En web,
  /// `signOut()` sin inicializar se queda esperando para siempre.
  static bool googleReady = false;

  Future<void> signOut() async {
    _api.token = null;
    _user = null;
    motos = const [];
    notifyListeners(); // primero la UI: la limpieza de abajo es best-effort
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {/* sin almacenamiento (tests) */}
    if (googleReady) {
      try {
        await GoogleSignIn.instance.signOut(); // para poder elegir otra cuenta
      } catch (_) {/* nada que cerrar */}
    }
  }
}
