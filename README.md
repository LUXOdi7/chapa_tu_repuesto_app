# ChapaTuRepuesto

Marketplace móvil que convierte el smartphone del mecánico en un mostrador
digital: catálogo por compatibilidad (marca / modelo / año), búsqueda por
dictado, comparación de ofertas entre tiendas, checkout y seguimiento del
pedido — todo contra la API REST del backend.

```bash
flutter run          # emulador Android -> http://10.0.2.2:8000
flutter run --dart-define=API_BASE_URL=http://192.168.1.45:8000   # celular físico
flutter test         # 7 checks: contrato, fechas UTC, moneda, carrito
flutter analyze      # sin issues
```

¿Flutter no arranca en esta PC? → **[flutter.md](flutter.md)** (instalación
manual, JDK, cmdline-tools, `local.properties`).
¿Qué endpoints existen y qué falta en el backend? → **[ANDROID.md](ANDROID.md)**.

## Cómo se conecta

```
Flutter (Android)  ──HTTP/JSON──►  FastAPI  ──SQL──►  MySQL
```

La app **no** habla SQL: todo pasa por los endpoints. La URL base sale de
`--dart-define=API_BASE_URL` con `http://10.0.2.2:8000` por defecto
(`lib/core/network/api_config.dart`).

En desarrollo la API es HTTP plano, por eso el `AndroidManifest.xml` lleva
`android:usesCleartextTraffic="true"`. **Quítalo al publicar con HTTPS.**

## Árbol del proyecto

```
lib/
├── main.dart                      # AppScope, rutas, y el shell segun el perfil
├── core/
│   ├── app_scope.dart             # inyección de dependencias (InheritedWidget)
│   ├── app_theme.dart             # Material 3 claro/oscuro, azul #1A365D + ámbar #F59E0B
│   ├── format.dart                # soles, fechas UTC->local, categorías
│   └── network/
│       ├── api_config.dart        # baseUrl (--dart-define) y URLs de imágenes
│       └── api_client.dart        # dio + Bearer + 401->logout + ApiException
├── shared/widgets/app_widgets.dart# PartImage, StockChip, AsyncView (carga/vacío/error)
└── features/
    ├── auth/       domain/user.dart · data/auth_repository.dart
    │               presentation/session.dart · login_page.dart
    ├── catalog/    domain/ (Product, Store, Compatibility)
    │               data/catalog_repository.dart
    │               presentation/ search_page · product_detail_page (+ ofertas)
    │                             widgets/ voice_search_bar (speech_to_text)
    │                                      compatibility_filters (cascada por API)
    ├── cart/       presentation/cart_store.dart   # local + persistido
    │               presentation/ cart_page · checkout_page
    ├── orders/     domain/order.dart  data/order_repository.dart
    │               presentation/ orders_page · order_tracking_page · receipt_page
    └── supplier/   data/supplier_repository.dart
                    presentation/ supplier_shell · store_form_page · product_form_page
```

## Decisiones que conviene conocer

| Tema | Cómo está resuelto |
|---|---|
| **Login** | `/auth/login` es form-urlencoded y `username` es el correo. Como JSON devuelve 422. |
| **Token** | JWT en `flutter_secure_storage`; al abrir la app se valida con `/auth/me`. Un 401 en cualquier petición borra la sesión y vuelve al login. |
| **Errores** | El backend manda `{"detail": "..."}` ya redactado en español: la app lo muestra tal cual en un SnackBar. |
| **Estados del pedido** | Los botones salen de `next_status`; la máquina de estados vive en el backend, no se duplica en la app. |
| **Checkout** | Devuelve **una lista**: un pedido por tienda. La confirmación los muestra por separado. |
| **Carrito** | Solo en la app (el backend no tiene tabla de carrito), persistido en el dispositivo. |
| **Fechas** | Llegan en ISO sin zona pero son UTC: `parseServerDate` las marca antes de pasarlas a local. |
| **Imágenes** | Se guarda la ruta relativa que devuelve `/uploads/image`; la URL se arma con la base URL. |

## Gestión de estado

`ChangeNotifier` (`Session`, `CartStore`) + `InheritedWidget` (`AppScope`) +
`AsyncView` para los estados de carga/vacío/error de cada pantalla. Todo del
framework, cero paquetes de estado.

**Al crecer: Riverpod.** Cuando entren caché, offline-first o sincronización
entre pantallas, `AsyncValue` y los providers componibles ahorran trabajo real.
Hoy no: el estado global son dos objetos.

## Atajos deliberados

Están marcados con comentarios `ponytail:` en el código, cada uno con su camino
de actualización. Los principales:

- **Constancia**: se dibuja desde `/orders/{id}/receipt` (JSON). El
  `receipt.html` del backend, listo para imprimir/PDF, entra cuando haga falta
  eso (ahí sí, con `webview_flutter` o `printing`).
- **Envío**: la regla (S/ 10 por tienda, gratis desde S/ 250) se repite en el
  carrito solo para previsualizar el total. El importe que se cobra es el que
  devuelve el checkout.
- **Sin `intl`**: `soles()` y las fechas son cuatro líneas en `core/format.dart`.
- **Sin `cached_network_image`**: `Image.network` ya cachea y `PartImage`
  degrada a icono.
- **Catálogo sin caché**: cada cambio de filtro pregunta al backend.

## Qué no está (y por qué)

| Falta | Motivo |
|---|---|
| Pago real | El backend expone pago simulado; ver `docs/INTEGRACIONES.md` §1 |
| Login con Google | El backend responde 501 hasta tener `GOOGLE_CLIENT_ID`; el botón ya maneja ese caso |
| Ficha pública de la tienda + reseñas | No está en las pantallas pedidas; los endpoints existen |
| Notificaciones push | Hoy los avisos del backend son correo |
