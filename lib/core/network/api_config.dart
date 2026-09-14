/// URL del backend. Configurable sin recompilar el codigo:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.45:8000
///
/// Por defecto apunta a `10.0.2.2`, que es como el emulador de Android ve a la
/// PC anfitriona. Un celular fisico necesita la IP real de la PC en la WiFi.
class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.1.195.229:9000',
  );

  /// Client ID de tipo WEB de Google Cloud (el mismo que `GOOGLE_CLIENT_ID`
  /// del backend). Vacio = el boton de Google avisa que falta configurarlo.
  ///
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// El backend guarda rutas relativas (`/uploads/products/ab12.jpg`) para que
  /// las imagenes sigan sirviendo si cambia de servidor: la URL completa se
  /// arma aqui.
  static String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
  }
}
