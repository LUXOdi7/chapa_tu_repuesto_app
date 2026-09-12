import 'package:dio/dio.dart';

import 'api_config.dart';

/// Error ya traducido para mostrar en pantalla.
///
/// El backend responde `{"detail": "mensaje en español"}` con el texto listo
/// para el usuario final, asi que la app no vuelve a redactarlo: solo cubre los
/// casos en los que no hay `detail` (sin red, timeout, 422 de validacion).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  factory ApiException.from(DioException e) {
    final response = e.response;

    if (response == null) {
      final timeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      return ApiException(
        timeout
            ? 'El servidor no respondio a tiempo (${ApiConfig.baseUrl}).'
            : 'No se pudo conectar con ${ApiConfig.baseUrl}.\n'
                'Revisa que el backend este encendido y que estes en la misma red.',
      );
    }

    final code = response.statusCode;
    final data = response.data;
    final detail = data is Map ? data['detail'] : null;

    // FastAPI devuelve una lista de errores de validacion en los 422: ese
    // formato no es mostrable, y ademas siempre es un bug de la app.
    if (detail is String && detail.isNotEmpty) {
      return ApiException(detail, statusCode: code);
    }
    if (code == 422) {
      return ApiException('Los datos enviados no son validos.', statusCode: code);
    }
    return ApiException(
      switch (code) {
        401 => 'Tu sesion vencio, vuelve a iniciar sesion.',
        403 => 'No tienes permiso para hacer esto.',
        404 => 'No encontramos lo que buscabas.',
        501 => 'Esa funcion todavia no esta disponible.',
        _ => 'Error del servidor ($code).',
      },
      statusCode: code,
    );
  }

  @override
  String toString() => message;
}

/// Unico punto de salida HTTP de la app.
///
/// Dos interceptores: uno pone el `Authorization: Bearer` en cada peticion
/// autenticada, el otro detecta el 401 (token vencido) y avisa a la sesion para
/// que borre el token y vuelva al login.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token;
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
        onError: (e, handler) {
          // Solo es "sesion vencida" si habia token: un 401 de /auth/login es
          // simplemente una contraseña incorrecta.
          if (e.response?.statusCode == 401 && token != null) {
            token = null;
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio _dio;

  /// JWT de la sesion. Lo escribe [Session]; null = sin sesion.
  String? token;

  /// Se dispara cuando el backend rechaza el token. Lo cablea [Session].
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  /// `/auth/login` es el UNICO endpoint que recibe form-urlencoded. Mandarlo
  /// como JSON devuelve 422, no 401.
  Future<dynamic> postForm(String path, Map<String, dynamic> fields) => _send(
        () => _dio.post<dynamic>(
          path,
          data: fields,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ),
      );

  Future<dynamic> postMultipart(String path, FormData form) =>
      _send(() => _dio.post<dynamic>(path, data: form));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Los filtros vacios no se mandan: `?category=` filtraria por cadena vacia.
  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((k, v) {
      if (v != null && v != '') out[k] = v;
    });
    return out;
  }
}

/// Azucar para las respuestas del backend, que siempre son objetos o listas.
Map<String, dynamic> asMap(dynamic data) => (data as Map).cast<String, dynamic>();

List<Map<String, dynamic>> asMapList(dynamic data) =>
    (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
