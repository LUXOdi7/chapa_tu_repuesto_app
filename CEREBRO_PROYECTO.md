# CEREBRO_PROYECTO — App Flutter ChapaTuRepuesto

Contexto compacto para un agente de código. Léelo antes de tocar nada. El
backend vive en `../Chapaturepuesto_BACKEND` (tiene su propio
CEREBRO_PROYECTO.md con endpoints y reglas de negocio).

## Qué es

App del marketplace de repuestos de moto. **Android y web** con el mismo
código (iOS solo si el dueño lo pide). Flutter 3.47 / Dart 3.13, Material 3,
sin gestor de estado: `AppScope` (InheritedWidget) reparte repositorios y dos
`ChangeNotifier` (`Session`, `CartStore`); dos `ValueNotifier` globales en
`main.dart` (`themeMode`, `shopMode`).

## Cómo correr / probar

- `flutter run --dart-define=API_BASE_URL=http://<IP_PC>:9000` (emulador
  `10.0.2.2`; web `-d chrome --web-port=5000` con `http://localhost:9000`).
  Opcional `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
- `flutter analyze` (debe quedar limpio) · `flutter test` (19 unitarios sin
  red) · E2E contra backend real: `flutter test test/live_admin_test.dart
  --dart-define=API_BASE_URL=http://localhost:9001 --dart-define=LIVE=true`
  (login admin, comprador completo, proveedor edita tienda, campana).
- `flutter build web` / `flutter build apk --debug` compilan.
- Guía funcional detallada: `GUIA_INTEGRACIONES_APP.md`.

## Estructura (`lib/`, 45 archivos)

| Ruta | Qué hay |
|---|---|
| `main.dart` | `ChapaTuRepuestoApp` (instancia repos + AppScope), `_Root` (splash / login / `AdminShell` / `SupplierShell` / `BuyerShell`; proveedor con `shopMode` = `BuyerShell(asSupplier: true)`), rutas con `onGenerateRoute`, `BuyerShell` (Buscar · Tiendas · Carrito · Pedidos) |
| `core/app_scope.dart` | DI: `api`, `session`, `auth`, `catalog`, `orders`, `suppliers`, `admin`, `cart` |
| `core/network/api_client.dart` | `dio` con Bearer y 401→logout; `ApiException` con `detail` del backend; **`stripNulls`** (los null no viajan en el body: el backend tiene defaults y un null da 422); `uploadImage(XFile, folder)` por bytes; `asDouble` (números que llegan como texto) |
| `core/network/api_config.dart` | `API_BASE_URL`, `GOOGLE_SERVER_CLIENT_ID`, `imageUrl(path)` para rutas relativas `/uploads/...` |
| `core/app_theme.dart` | Azul `#1A365D` + naranja del logo `#F4731A` (`kBrandAmber`); superficies suaves, inputs/cards con borde, NavigationBar con indicador naranja. **`FilledButton` tiene ancho infinito por tema**: dentro de `Row`/`Wrap`/`trailing` usar `OutlinedButton`/`TextButton` o envolver en `Expanded` |
| `core/format.dart` | `soles()`, `parseServerDate` (backend manda UTC sin zona), `shortDate/dateTimeLabel/timeLabel/dayLabel/sameDay`, **`categoryLabels` mapa global mutable** (lo llena `CatalogRepository.loadCategories()` vía `Session.refreshMotos`; `createCategory` lo actualiza), `categoryLabel/knownCategories` |
| `shared/widgets/app_widgets.dart` | `AsyncView` (loading/error/vacío con `refreshKey`), `PartImage`, `StockChip`, `SectionTitle`, `BrandTitle` (isotipo + título en AppBars), `BrandLogo` (login/splash), `showError/showInfo` |
| `assets/` | `ctr_logo.png` (logo completo, fondo transparente), `ctr_mark.png` (isotipo), `ctr_icon.png` (launcher; `dart run flutter_launcher_icons` regenera Android + web) |
| `shared/widgets/map_picker_page.dart` | `MapPickerPage` (elegir lat/lng tocando OSM) y `StoreMap` (mapa fijo). `flutter_map`, sin API key |
| `features/auth` | `User`/`UserRole`/`UserMoto`, `AuthRepository` (login form-urlencoded, register, google, forgot/reset, perfil, motos, notificaciones, feedback), `Session` (token en secure storage, `motos` cacheadas, `googleReady`, `signOut` notifica primero), `LoginPage` (Google: `authenticate()` Android / `attemptLightweightAuthentication()` web), `ForgotPasswordPage` |
| `features/catalog` | `Product/ProductPage(parsed)`, `Store/StoreReview`, `Compatibility`; `CatalogRepository` (+alertas); `SearchView` (voz `speech_to_text`, cascada `CompatibilityFilters` (**tipo de moto** → marca → modelo → año) con `select()`, chips de mis motos, chips "Entendí:"; **"Ver más" = última celda de la grilla que agrega páginas a `_extra` sin reiniciar el `AsyncView`**), `ProductDetailPage` (galería `_Gallery` con puntos si hay varias fotos, ofertas, "Compatible con tu…", campana de alerta), `StorePage`/`StoresView` (mapa, Cómo llegar por URL de Google Maps, Llamar) |
| `features/cart` | `CartStore` persistido, agrupado por tienda; `CartView`, `CheckoutPage` |
| `features/orders` | `Order` (events, buyer, messageCount, canReviewBuyer, storeHasGateway), `ChatMessage`; `OrderRepository` (checkout, list `asBuyer`, `startPayment`, pay manual, `receiptPdfUrl`, messages, reviewBuyer); `OrdersView`, `OrderTrackingPage` (stepper con fechas, pagar → abre `checkout_url` con `url_launcher`, PDF, chat, calificar), `ChatPage` (polling 4 s `after_id`, chip de fecha una vez por día, hora en burbuja), `ReceiptPage` |
| `features/supplier` | `SupplierRepository`; `SupplierShell` (Tienda con KPIs/cobro/verificación + **"Ver mi perfil público"** (reusa `StorePage`: mapa, calificaciones, comentarios) · Pedidos · Repuestos **agrupados por categoría (`ExpansionTile`, alfabético dentro)**; botón "Comprar" → modo comprador), `StoreFormPage` (logo, mapa, lat/lng), `ProductFormPage` (galería hasta 5 fotos con `pickMultiImage`, tocar miniatura = portada; botón "+" crea categoría; compatibilidades; **al editar se carga el producto completo** para no perder compatibilidades), `PaymentConfigPage` |
| `features/profile` | `ProfilePage` (avatar, editar datos, mis motos, alertas, modo comprador, tema, sugerencia, salir), `MyMotosPage`, `AlertsPage` + `showCreateAlertDialog`, `NotificationsPage` + `NotificationBell` (badge cada 30 s, recargar, marcar todas, tocar → pedido) |
| `features/admin` | `AdminRepository`, `AdminShell` (Resumen con chips de categorías + "Nueva" · Usuarios · Tiendas · Pedidos · Ideas). El panel web admin es este mismo código con `flutter build web` |

## Contrato con el backend (lo que la app asume)

- Errores: `{"detail": "texto en español"}` → se muestra tal cual en SnackBar.
- `next_status` del pedido ya viene filtrado por rol: los botones salen de ahí.
- Imágenes: rutas relativas `/uploads/<folder>/x.jpg`; la app antepone base URL.
- Pagos: `storeHasGateway` (MP/Niubiz) → `/payments/{id}/start` y abrir URL;
  si no, diálogo manual con nº de operación.

## Dependencias (todas sirven en Android y web)

`dio`, `flutter_secure_storage`, `image_picker`, `speech_to_text`,
`google_sign_in` 7, `url_launcher`, `flutter_map` + `latlong2`. No hay
Firebase (push por polling/correo hasta que exista proyecto FCM).

## Convenciones para el agente

- No leer `AppScope`/`ScaffoldMessenger` en `initState` (usar `Future.microtask`).
- Parchear con scripts Python; `dart format` cambia indentación de algunos
  archivos (domain/), comprobar antes de buscar texto.
- Tras cambios de UI: `flutter analyze`, `flutter test`, y si toca flujo,
  el E2E `LIVE=true` contra el backend con seed.

## Bitácora de indicaciones del dueño (cronológica)

- 2026-09-14 · MVP completo con vistas por rol (admin / proveedor con modo
  comprador / comprador); Google, recuperación, panel proveedor, voz, ofertas,
  carrito, pagos, PDF, seguimiento, calificación; guías de integración.
- 2026-09-14 · Fixes: admin crasheaba (FilledButton en trailing), `Decimal`
  como texto, logout web colgado, PDF/foto/Google en web, subida de imágenes
  (mount capturaba el POST), voz tipo YouTube con chips "Entendí".
- 2026-09-14 · Mis motos, chat por pedido, alertas, reputación en dos vías.
- 2026-09-14 · Foto de perfil y logo; edición de perfil/tienda (422 por
  nulls); mapa OSM interactivo; CRUD revisado.
- 2026-09-15 · Toasts descriptivos (no borrar producto en compra); campana de
  notificaciones junto al icono de usuario con recargar; chat con fecha una
  vez por día y hora en burbuja; aviso por cambio de nombre de producto.
- 2026-09-15 · Mantener este archivo actualizado con cada indicación nueva.
- 2026-09-15 · En la raíz `D:\ChapaTuRepuesto` (fuera de los repos): `INSTALACION.md`
  (manual desde cero: versiones, Docker, venv, ctr, Flutter, workspace VS Code)
  y `Sugerencias-A-IMPLEMENTAR.md` (ideas priorizadas A–F).
- 2026-09-15 · `CONTEXTO-ACTUAL-PROYECTO.md` en la raíz: explicación completa del
  proyecto para el equipo (roles, BD, flujo de pedido, imágenes, voz,
  notificaciones, pruebas). Actualizarlo cuando cambie algo de fondo.
- 2026-09-20 · Perfil público de la tienda desde su panel; hasta 5 fotos por
  producto; categorías dinámicas (admin y tiendas; "Accesorios"); repuestos del
  proveedor agrupados por categoría y alfabéticos; "Ver más" sin reiniciar la
  grilla; tema con colores del logo `CTR_LOGO.png` (assets + launcher icons).
  Google: client ID web ya en `.vscode/launch.json` (Cristian) y en `.env` del
  backend. FCM: no existe (sin Firebase).
- 2026-09-20 · Login con logo de fondo blanco (`ctr_logo_white.png`); tarjetas
  del resumen admin compactas (grilla de alto fijo). `INSTALACION.md §4`: cómo
  activar Google (SHA-1 por compañero, puerto 5000) y el correo de Lucía.
- 2026-09-20 · Google en web: boton oficial `renderButton` (popup) via
  `auth/presentation/google/` (import condicional web/stub) + stream
  `authenticationEvents`; web solo `clientId`, Android solo `serverClientId`.
  El client ID viaja en `GET /health` (`google_client_id`): la app ya no
  necesita `--dart-define` para Google.
- 2026-09-22 · Buscador por voz: la palabra de categoría ahora **filtra**
  (antes solo sumaba puntos, "muéstrame accesorios" daba 0), acepta singular
  y plural (electrico/electricos) y se ignoran verbos de relleno
  (tienes/hay/cuesta/cuánto…). Ejemplos probados en el README del backend.
- 2026-09-22 · Dictado en web arreglado: `pauseFor` (3 s) cortaba la escucha
  porque la Web Speech API no emite nivel de sonido; ahora `pauseFor` solo en
  Android, idioma forzado `es-PE` y `onError`/`onStatus` conectados
  (`speechErrorText`). Recordar: en web el micro exige localhost/https.
- 2026-09-22 · Marca del repuesto visible junto al código en tarjetas del
  buscador, carrito, pedido y constancia (`brandAndCode`); `order_items.brand`
  congela la marca al comprar (**requiere `ctr reset`**). Brave bloquea el
  dictado: aviso a los 8 s sin audio + texto explicando cómo activarlo.
- 2026-09-22 · El backend ya migra columnas solo; correo de pedido limitado a
  pagado/entregado/cancelado (la campana sigue recibiendo todo).
- 2026-09-22 · Tres tipos de moto en toda la app: filtro de tipo en el buscador,
  selector en el diálogo de compatibilidad del proveedor, tipo en "Mis motos" y
  en los chips de la ficha (`motoTypeLabels/motoTypeIcons` en format.dart).
  Perfil del comprador: dirección guardada con selector de mapa; checkout deja
  elegir esa o una nueva para el pedido, ambas con punto en el mapa.
- 2026-09-17 · `PENDIENTE.md` en la raíz: checklist de servicios/credenciales que
  faltan (Google, SMTP, MP, Niubiz, dominio, keystore, legales, FCM, Yape vía
  pasarela, RUC API, mapas, Sentry, SUNAT) con cómo conseguir cada clave.
- 2026-09-25 · Merge de CRISTIAN (FCM): firebase_core/firebase_messaging/
  flutter_local_notifications, `google-services.json`, plugin gms 4.5.0 y
  `lib/core/notifications/firebase_notifications.dart` (canal
  `chapaturepuesto_notifications`). `Session.registerFcmToken()` sube el token a
  `PUT /auth/me/device` al entrar y al restaurar sesión. **Arreglado:** su
  `main()` llamaba `Firebase.initializeApp()` sin opciones y en web reventaba
  antes de `runApp` (pantalla en blanco, "Null check operator used on a null
  value"); ahora va dentro de `if (!kIsWeb) { try { ... } }`, así que web
  arranca y Android sobrevive sin `google-services.json`. Push = solo Android;
  en web la campana cubre lo mismo. Ojo: `flutter build web` compila igual con
  ese bug, hay que **abrir** la web para detectarlo. Guía en la raíz:
  `VERIFICAR-CAMBIOS-CRISTIAN.md`.
- 2026-09-25 · **Pestaña "Estadísticas" en el panel de la tienda**
  (`stats_page.dart`): KPIs, barras de venta y de pedidos por día, rankings de
  repuestos / categorías / clientes, dona de estados y aviso de stock bajo.
  Gráficas propias en `shared/widgets/charts.dart` (`DailyBars`, `RankingBars`,
  `DonutChart`, `StatTile`) — widgets + un CustomPainter, **sin sumar fl_chart**.
  Test con la respuesta REAL del backend en celular y escritorio
  (`supplier_stats_test.dart`); encontró dos desbordes que ya están corregidos.
- 2026-09-25 · **design.md aplicado** (`/ui-ux-pro-max:brand`): `app_theme.dart`
  usa los tokens exactos (claro #F8FAFC/#FFFFFF/#0F172A/#64748B/#E2E8F0, oscuro
  #0B1120/#1E293B/#F8FAFC/#94A3B8/#334155), naranja #F4731A como color de
  interacción, botones radio 10, inputs con relleno #F1F5F9 y foco naranja 2px,
  cards planas con borde y sombra 0.05. Nuevo `AdaptiveScaffold`: NavigationBar
  en móvil y **NavigationRail azul** desde 600 px (extendido desde 900) en las
  tres pantallas raíz. `FormBox` limita los formularios a 600 px en escritorio.
  `BrandLoader` (isotipo girando) reemplaza al CircularProgressIndicator y el
  estado vacío lleva un engranaje naranja.
- 2026-09-25 · `GUIA_WEB_CEL.md` en la raíz: cómo correr Chrome y el celular a
  la vez. **`flutter run -d all` NO sirve** (ignora web y escritorio, probado):
  son dos terminales. Alternativa de una sola terminal:
  `-d web-server --web-hostname 0.0.0.0`, pero por IP el navegador no da
  micrófono ni GPS. Ojo: la IP de la PC cambió de 192.168.1.18 a 192.168.1.92.
- 2026-09-25 · **Bug en Android al dictar** (pantalla roja
  `navigator.dart:5949 '!_debugLocked'`, que es el assert de
  `NavigatorState.build`): la hoja de dictado tenía TRES salidas —botón
  "Usar lo dictado", `onResult` final y el estado `done`/`notListening`— y en
  Android llegan casi juntas, así que se hacía un segundo `Navigator.pop`
  sobre la ruta que ya se estaba cerrando y el Navigator se reconstruía
  bloqueado. Arreglo: un único `_close(heard)` con cerrojo `_closed` en
  `voice_search_bar.dart`. De paso, la hoja ahora va en
  `SingleChildScrollView` (con el aviso de error se desbordaba 19 px y tapaba
  los botones). Test `voice_search_test.dart`: simula la carrera por el canal
  `plugin.csdcorp.com/speech_to_text` con el buscador en una ruta empujada;
  **verificado que falla si se quita el cerrojo**.
- 2026-09-28 · `DESPLIEGUE.md` en la raíz: guía para producción. Flutter web
  build con `--dart-define=API_BASE_URL=<URL-Railway>` → Netlify.
  GitHub Actions en `.github/workflows/deploy_web.yml` auto-despliega al hacer
  push a main (secrets: API_BASE_URL, NETLIFY_AUTH_TOKEN, NETLIFY_SITE_ID).
  APK build local con mismo dart-define → GitHub Releases o Firebase App
  Distribution. Keystore en `android/chapaturepuesto.jks` + `key.properties`.
- 2026-09-25 · **Mensaje duplicado en el chat del pedido** (solo lo veía quien
  escribía): el refresco de 4 s sale con el `after_id` de antes; si respondía
  después del envío, traía de vuelta el mensaje que `_send` ya había agregado.
  Arreglo en `chat_page.dart`: un único `_merge(news)` **deduplicado por id**
  por el que pasan el envío, el poll y el botón de recargar (también cubre dos
  refrescos solapados). Test `chat_page_test.dart`, verificado en los dos
  sentidos: sin el dedupe salen 2 burbujas, con él 1.
