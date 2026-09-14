# Guía de funcionalidades e integraciones — App Flutter

Qué hace cada pantalla, qué servicio externo necesita y qué hay que
configurar (en la app y en el backend) para que funcione con datos reales.
Lo que toca al servidor está en `Chapaturepuesto_BACKEND/docs/INTEGRACIONES.md`.

## 1. Cómo se arranca

```powershell
# Backend (carpeta Chapaturepuesto_BACKEND)
.\ctr run      # MySQL + API en Docker
.\ctr reset    # datos demo (admin@demo.pe / proveedor1@demo.pe / taller.julio@demo.pe, clave 123456)
.\ctr lan      # IP para el celular físico

# App
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<IP_DEL_PC>:9000
# emulador Android: http://10.0.2.2:9000
```

Variables `--dart-define` que entiende la app (`lib/core/network/api_config.dart`):

| Variable | Para qué | Sin ella |
|---|---|---|
| `API_BASE_URL` | URL del backend | Usa el valor por defecto del archivo |
| `GOOGLE_SERVER_CLIENT_ID` | Client ID **web** de Google Cloud (el mismo `GOOGLE_CLIENT_ID` del `.env` del backend) | El botón "Continuar con Google" avisa que falta configurarlo |

Para no escribirlas cada vez, en Android Studio: *Run → Edit Configurations →
Additional run args*: `--dart-define=API_BASE_URL=... --dart-define=GOOGLE_SERVER_CLIENT_ID=...`

---

## 2. Vistas por tipo de usuario

`lib/main.dart` → `_Root` decide con `user.role`:

| Perfil | Pantalla raíz | Pestañas |
|---|---|---|
| `buyer` | `BuyerShell` | Buscar · Tiendas · Carrito · Pedidos |
| `supplier` | `SupplierShell` | Tienda (resumen, cobro) · Pedidos de mi tienda · Repuestos |
| `supplier` en **modo comprador** | `BuyerShell(asSupplier: true)` | Igual que comprador; "Pedidos" muestra sus compras (`/orders?as_role=buyer`) |
| `admin` | `AdminShell` | Resumen · Usuarios · Tiendas · Pedidos · Ideas |

- **Cambiar de modo** (proveedor): botón "Comprar" en la barra del panel, o el
  switch en *Mi cuenta*. Es un `ValueNotifier<bool> shopMode` global; el
  backend ya permite que un proveedor compre (menos en su propia tienda).
- **Mi cuenta** (`features/profile`): editar nombre/teléfono/contraseña, tema,
  enviar sugerencia (`POST /feedback`), cerrar sesión. Compartida por los 3 roles.
- El admin no se registra desde la app: `.\ctr admin correo clave` en el backend.

---

## 3. Funcionalidades del MVP y qué necesitan

### 3.1 Registro e inicio de sesión

| Función | Archivo | Servicio externo |
|---|---|---|
| Correo + contraseña | `auth/presentation/login_page.dart` | Ninguno (bcrypt en backend) |
| Google | `login_page.dart` → `GoogleSignIn.instance.authenticate()` | **Google Cloud Console** (ver 4.1) |
| Recuperar contraseña por código | `auth/presentation/forgot_password_page.dart` | **SMTP en el backend** (sin SMTP el código sale en `ctr logs`) |

### 3.2 Panel del proveedor

| Función | Archivo | Endpoint |
|---|---|---|
| Registrar tienda (RUC, dirección, horario, contacto, **lat/lng**, descripción) | `supplier/presentation/store_form_page.dart` | `POST /suppliers/store` |
| Resumen (por despachar, repuestos, sin stock, vendido) | `supplier_shell.dart` → `_StoreTab` | `GET /suppliers/dashboard` |
| Publicar/editar repuesto con foto y compatibilidades | `product_form_page.dart` | `POST/PUT /suppliers/products`, `POST /uploads/image` |
| Bandeja de pedidos y avance de estados | `orders/presentation/orders_page.dart`, `order_tracking_page.dart` | `GET /orders`, `PATCH /orders/{id}/status` |

Las coordenadas se escriben a mano (en Google Maps: mantener pulsado sobre el
local → copiar "lat, lng"). Con ellas el comprador ve **"Cómo llegar"**.

### 3.3 Medio de cobro (núcleo del negocio)

`supplier/presentation/payment_config_page.dart` → `PUT /suppliers/store/payment`.

El proveedor elige **Mercado Pago** (pega su Access Token) o **Niubiz**
(merchantId, usuario, clave). El backend las cifra; la app solo ve
`payment_configured: true`. Qué debe solicitar el proveedor: ver 4.2 y 4.3.

### 3.4 Catálogo, buscador por compatibilidad y voz

`catalog/presentation/search_page.dart`. Filtros en cascada marca → modelo →
año, categoría, stock, orden. El **dictado** (`voice_search_bar.dart`,
`speech_to_text`) manda el texto a `q`; el backend busca **cada palabra** en
nombre, descripción, marca, código y moto compatible, así "pastillas pulsar
2020" funciona dictado de corrido. No necesita ningún servicio: usa el
reconocedor de voz del teléfono (permiso `RECORD_AUDIO`, ya en el manifest).

### 3.5 Ficha de producto y comparación de ofertas

`product_detail_page.dart`. `offers` = misma pieza (`part_code`) en otras
tiendas ordenadas por precio y cercanía; el nombre de la tienda abre su perfil.

### 3.6 Perfil de tienda y directorio

`catalog/presentation/store_page.dart`: `StorePage` (datos, calificaciones,
catálogo, **Cómo llegar**, **Llamar**) y `StoresView` (pestaña Tiendas con
buscador y filtro de verificadas). "Cómo llegar" abre Google Maps con
`url_launcher` (URL `maps/dir/?api=1&destination=lat,lng`); no hace falta API
key ni SDK de mapas.

### 3.7 Carrito y orden

`cart/`: agrupado por tienda; `POST /orders/checkout` devuelve **una orden por
proveedor** (`CTR-000000`) con subtotal y envío.

### 3.8 Pago

`orders/presentation/order_tracking_page.dart` → `_pay`:

| Caso | Qué hace la app | Endpoint |
|---|---|---|
| Tarjeta y la tienda tiene pasarela | `POST /payments/{id}/start` → abre `checkout_url` en el navegador con `url_launcher`. Al volver, "Actualizar": el backend ya aprobó el pedido por webhook (MP) o retorno (Niubiz) | `/payments/{id}/start` |
| Tarjeta y la tienda NO tiene pasarela | Se aprueba al instante (simulado) | `/payments/{id}/start` |
| Yape / transferencia | Diálogo con nº de operación → pago verificado provisional; el proveedor confirma | `/orders/{id}/payment` |

Split payment: como cada orden es de una sola tienda, cada pago va con las
credenciales de esa tienda a su cuenta. Un carrito con 3 tiendas = 3 pedidos
= 3 pagos.

### 3.9 Verificación del pago y constancia

Tras `payment_verified` aparecen **Ver constancia** (JSON dibujado) y
**Descargar PDF**: la app pide `GET /orders/{id}/receipt-link` (enlace firmado
de 10 min) y lo abre con `url_launcher`, igual en Android (visor/navegador) y
en web (nueva pestaña). Comprador y proveedor lo pueden descargar.

### 3.10 Seguimiento

Stepper con los 6 estados; cada paso muestra la **fecha real** en que ocurrió
(`events` del backend). Los botones salen de `next_status`, que el backend
calcula para ESTE usuario. Botones extra: Ver tienda, Cómo llegar.

### 3.11 Notificaciones y calificación

Correos automáticos los manda el backend (necesita SMTP). La calificación al
cerrar está en `order_tracking_page.dart` → `_review`.

### 3.12 Mis motos

`profile/presentation/my_motos_page.dart` (misma cascada marca → modelo → año
del catálogo) → `POST /auth/me/motos`. La sesión las cachea
(`Session.motos`): el buscador muestra un chip por moto (un toque = filtro
completo, encabezado "compatibles con tu …") y la ficha marca "Compatible con tu
Pulsar NS 200" cuando alguna compatibilidad declarada la incluye.

### 3.13 Chat por pedido

`orders/presentation/chat_page.dart`: burbujas, envío y refresco cada 4 s
con `after_id` (solo lo nuevo). Botón "Consultar / Mensajes (N)" en el
seguimiento. Quien recibe tiene aviso por correo; push con FCM: ver
`docs/INTEGRACIONES.md §6` del backend (necesita proyecto Firebase).

### 3.14 Alertas de stock / precio

Campana en la ficha → `showCreateAlertDialog` (`profile/presentation/alerts_page.dart`)
→ `POST /alerts`. Lista y borrado en *Mi cuenta → Mis alertas*. El aviso llega
por correo cuando una tienda edita el producto y cumple la condición.

### 3.15 Reputación en dos vías

La tienda, en el seguimiento de un pedido entregado/cerrado, ve
"Calificar comprador" (`_reviewBuyer`) → `POST /orders/{id}/buyer-review`. La
calificación aparece junto al nombre del comprador en cada pedido de la tienda
y en *Mi cuenta* del comprador.

### 3.16 Foto de perfil y logo de la tienda

*Mi cuenta* → tocar el avatar → `image_picker` → `ApiClient.uploadImage(file, folder: 'avatars')`
→ `PATCH /auth/me {avatar_url}`. *Editar tienda* → tocar el círculo del logo →
`folder: 'logos'`. Todo cae en `uploads/<folder>/` del backend; la app guarda la
ruta relativa y la resuelve con `ApiConfig.imageUrl`.

### 3.17 Ubicación en mapa (OpenStreetMap)

`shared/widgets/map_picker_page.dart` (`flutter_map`, sin API key). *Editar
tienda → Marcar mi tienda en el mapa* → tocar → *Usar* rellena lat/lng. La
ficha pública muestra `StoreMap` con el marcador. Política de uso de OSM y
proveedores con clave: `solicitud_servicios.md §7` del backend.

### 3.18 Panel admin en web

Es el mismo `AdminShell`: `flutter build web` y servir `build/web` (Caddy,
Nginx o `python -m http.server`). Entrar con la cuenta admin.


---

## 4. Servicios externos: qué solicitar y dónde ponerlo

### 4.1 Google Sign-In

1. Google Cloud Console → proyecto → **Pantalla de consentimiento OAuth**
   (externo, nombre ChapaTuRepuesto).
2. **Credenciales → ID de cliente OAuth**:
   - **Android**: paquete `com.negocios.chapaturepuesto` (ver
     `android/app/build.gradle.kts`) + SHA-1. Obtenerlo:
     `cd android && .\gradlew signingReport` (fila `debug` → `SHA1`). Para
     release, la huella del keystore de firma.
   - **Aplicación web**: copia su ID.
3. App: `--dart-define=GOOGLE_SERVER_CLIENT_ID=<ID web>`.
   Backend: `GOOGLE_CLIENT_ID=<ID web>` en `.env` y `.\ctr run`.
4. `google_sign_in` 7.x ya está en `pubspec.yaml`; no requiere `google-services.json`.
5. **Web**: en el cliente OAuth *Aplicación web* añade como *Origen autorizado de
   JavaScript* la URL donde corre la app (`http://localhost:PUERTO` en desarrollo;
   usa `flutter run -d chrome --web-port=5000` para que sea fijo). En web el
   botón usa el One Tap de Google (`attemptLightweightAuthentication`).

Errores típicos: `DEVELOPER_ERROR` / código 10 = SHA-1 o paquete no coinciden
con el cliente Android; `idToken == null` = falta el `serverClientId`.

### 4.2 Mercado Pago (lo solicita cada proveedor)

1. Cuenta en mercadopago.com.pe → **Tus integraciones → Crear aplicación**
   (Checkout Pro).
2. **Credenciales de producción → Access Token** (`APP_USR-…`). Para probar,
   credenciales de prueba + usuarios de prueba.
3. En la app: *Mi tienda → Medio de cobro → Mercado Pago → pegar token*.
4. El backend debe tener `BASE_URL` pública HTTPS (o `ngrok`) para recibir el
   webhook. Sin eso el pago se cobra pero el pedido no se aprueba solo.

### 4.3 Niubiz (lo solicita cada proveedor)

1. Afiliación comercial con Niubiz (RUC, cuenta bancaria). Entregan
   **merchantId**, **usuario** y **clave** de API (sandbox primero).
2. En la app: *Medio de cobro → Niubiz → los tres datos*.
3. El checkout es una página web que sirve el backend
   (`/payments/{id}/niubiz/checkout`); la app la abre con `url_launcher`.

### 4.4 Correo (backend)

Gmail con contraseña de aplicación, Brevo o SES: variables `SMTP_*` del
backend. Afecta a: código de recuperación y avisos de cada estado.

### 4.5 Permisos y paquetes ya configurados

| Paquete | Uso | Android |
|---|---|---|
| `speech_to_text` | Dictado | `RECORD_AUDIO` + `queries RecognitionService` |
| `image_picker` | Foto del repuesto | — |
| `google_sign_in` | Login Google | Cliente OAuth Android (SHA-1) |
| `url_launcher` | Checkout, Cómo llegar, Llamar | `queries` VIEW https / DIAL tel (ya en manifest) |
| `flutter_map` + `latlong2` | Mapa OSM (elegir ubicación, ficha de tienda) | — (tiles públicos con User-Agent) |
| `flutter_secure_storage` | JWT y carrito | — |
| `dio` | HTTP con Bearer, multipart y bytes | `usesCleartextTraffic` para HTTP en desarrollo |

---

## 5. Contrato: campos nuevos del backend que usa la app

| Endpoint | Campo | Uso en la app |
|---|---|---|
| `/auth/me` | `store_id`, `avatar_url`, `is_active` | Perfil |
| `/orders/*` | `events[]`, `buyer{}`, `payment_provider`, `store.payment_provider`, `store.latitude/longitude` | Timeline con fechas, datos del comprador para el proveedor, decidir pasarela vs manual, Cómo llegar |
| `/catalog/stores`, `/catalog/stores/{id}` | `latitude`, `longitude`, `description`, `product_count` | Directorio y perfil de tienda |
| `/suppliers/store` | `payment_configured`, `verified` | Estado del cobro y aviso de verificación |
| `/suppliers/dashboard` | `pending_to_ship`, `products`, `out_of_stock`, `total_sold`, `orders_by_status` | KPIs del panel |
| `/admin/*` | ver README del backend | `features/admin` |

---

## 6. Android y web: qué cambia

Todo funciona en las dos plataformas con el mismo código. Diferencias internas:

| Función | Android | Web |
|---|---|---|
| Login Google | `authenticate()` (selector de cuenta) | `attemptLightweightAuthentication()` (One Tap) + `clientId` |
| PDF | `url_launcher` abre el visor | `url_launcher` abre pestaña |
| Foto del repuesto | `image_picker` galería | `image_picker` diálogo de archivo; se suben bytes, no ruta |
| Dictado | reconocedor del sistema | Web Speech API (Chrome) |
| Token / carrito | EncryptedSharedPreferences | WebCrypto en `localStorage` (requiere `localhost` o HTTPS) |
| Cómo llegar / Llamar | app de mapas / marcador | Google Maps en pestaña / `tel:` |
| Backend | `http://10.0.2.2:9000` o IP LAN | `http://localhost:9000` (CORS `*` ya configurado) |

Probar en web: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:9000`.

## 7. Antes de publicar en Play Store

1. `applicationId` propio y keystore de release (`android/app/build.gradle.kts`).
2. Quitar `usesCleartextTraffic` y apuntar `API_BASE_URL` a HTTPS.
3. Cliente OAuth Android con el SHA-1 del keystore de release.
4. Política de privacidad publicada (Google la exige por el micrófono y el login).
