# Conectar la app Flutter (Android Studio) con este backend

Esta guía tiene tres partes:

1. **Cómo se conecta la app a la base de datos** (spoiler: no se conecta directo).
2. **El prompt** que le pegas a Claude en Android Studio.
3. **Lo que tienes que configurar tú** en el proyecto Flutter y cómo verificar
   que los movimientos quedan guardados en MySQL.

---

## 1. Cómo se conecta la app a la base de datos

**La app Flutter NO se conecta a MySQL.** Nunca, ni en desarrollo. La cadena es:

```
Flutter (Android)  ──HTTP/JSON──►  FastAPI (este repo)  ──SQL──►  MySQL (Laragon)
```

Por qué no directo:

- Un APK se puede descompilar en minutos: las credenciales de MySQL quedarían a
  la vista de cualquiera y con ellas se puede borrar toda la base.
- Habría que exponer el puerto 3306 a internet, que es exactamente lo que los
  atacantes buscan.
- Las reglas del negocio (stock, estados del pedido, quién ve qué pedido) viven
  en el backend. Si la app hablara SQL, cada dispositivo podría saltárselas.

Así que "conectar con la BD" desde la app significa: **llamar a los endpoints de
esta API**. Todo lo que la app haga —registrarse, publicar un repuesto, comprar,
cambiar un estado— queda guardado en las tablas de MySQL, y se puede verificar en
HeidiSQL al instante.

### Antes de programar: levanta el backend

```powershell
# 1. Enciende MySQL desde Laragon
# 2. En D:\Chapaturepuesto_BACKEND
.\ctr reset      # base limpia + datos simulados
.\ctr lan        # levanta la API en 0.0.0.0:8000 y muestra tu IP local
```

`ctr lan` imprime algo como `http://192.168.1.45:8000`. Esa es la URL que usa un
**celular físico** en la misma red WiFi. En el **emulador** de Android Studio la
URL es siempre `http://10.0.2.2:8000` (así es como el emulador ve tu PC).

Comprueba desde el navegador del celular que `http://TU_IP:8000/health` responde
`{"status":"ok"}`. Si no responde, es el Firewall de Windows: permite Python en
redes privadas.

---

## 2. Prompt para Claude en Android Studio

Copia todo el bloque siguiente y pégalo en Android Studio, dentro del proyecto
Flutter de ChapaTuRepuesto.

---

````text
Actúa como desarrollador Senior en Flutter/Dart. Este proyecto ("ChapaTuRepuesto")
ya tiene las pantallas construidas con datos mockeados. Tu trabajo ahora es
CONECTARLO a un backend REST real que ya está funcionando, y eliminar los mocks.

No inventes endpoints ni campos: el contrato que está más abajo es exacto, fue
tomado de respuestas reales del servidor. Si algo que necesitas no está en el
contrato, dímelo en vez de inventarlo.

## Backend

- FastAPI + MySQL, ya corriendo. Documentación viva en http://127.0.0.1:8000/docs
- Base URL:
  - Emulador Android: http://10.0.2.2:8000
  - Celular físico en la misma WiFi: http://<IP_DEL_PC>:8000
  - Debe ser configurable con --dart-define=API_BASE_URL=..., con 10.0.2.2 por defecto.
- Es HTTP plano en desarrollo: hay que habilitar cleartext traffic en Android.

## Reglas de la integración

1. Autenticación por JWT (Bearer). El token se guarda con flutter_secure_storage
   y se envía en el header Authorization de TODA petición autenticada.
2. IMPORTANTE: /auth/login NO recibe JSON. Recibe application/x-www-form-urlencoded
   con los campos `username` (que es el CORREO) y `password`. Todos los demás
   endpoints sí usan JSON.
3. Los importes de dinero llegan como número (double), no como string. Formatéalos
   con intl como "S/ 1,234.50".
4. Las fechas llegan en ISO 8601 sin zona horaria y están en UTC:
   DateTime.parse(x).toLocal().
5. Los enums llegan en minúscula y en inglés (buyer, supplier, frenos, created,
   payment_verified...). No los muestres crudos: usa el campo status_label que ya
   viene traducido, y traduce las categorías en la UI.
6. Los errores llegan como {"detail": "mensaje en español"} con código HTTP:
   401 sesión vencida (redirigir al login), 403 sin permiso, 404 no existe,
   409 conflicto de negocio (sin stock, transición de estado inválida).
   Muestra `detail` en un SnackBar, ya viene redactado para el usuario final.
7. El carrito vive SOLO en la app (estado local, persistido en el dispositivo).
   El backend no tiene tabla de carrito: recibe el carrito completo al pagar.

## Contrato de la API

### Autenticación

POST /auth/register  (JSON, público) -> 201
  {"name":"Taller Don Julio","email":"a@b.pe","password":"123456","phone":"979...","role":"buyer"}
  role: "buyer" (mecánico/motociclista) o "supplier" (tienda)
  Respuesta (igual que login):
  {"access_token":"eyJ...","token_type":"bearer",
   "user":{"id":6,"name":"Taller Mecanico Don Julio","email":"taller.julio@demo.pe",
           "phone":"979887766","role":"buyer"}}
  409 si el correo ya existe.

POST /auth/login  (FORM-URLENCODED, público) -> 200
  username=<correo>&password=<clave>     ← ojo: form, no JSON
  Misma respuesta que register. 401 si las credenciales son inválidas.

GET  /auth/me  (Bearer) -> {"id":6,"name":"...","email":"...","phone":"...","role":"buyer"}

POST /auth/google  (JSON, público) {"id_token":"..."} -> misma respuesta que login.
  Hoy devuelve 501 porque falta configurar GOOGLE_CLIENT_ID. Deja el botón, pero
  maneja el 501 mostrando "Inicio con Google no disponible todavía".

### Catálogo (público, sin token)

GET /catalog/categories -> ["motor","frenos","transmision","electrico","carroceria","llantas","lubricantes"]
GET /catalog/moto-brands -> ["Bajaj","Honda","Italika","Yamaha","Zongshen"]
GET /catalog/moto-models?moto_brand=Honda -> ["CB 125F","Wave 110S","XR 150L"]
GET /catalog/moto-years?moto_brand=Honda&moto_model=XR 150L -> [2025,2024,...,2015]
  (estos tres alimentan los filtros en cascada Marca -> Modelo -> Año)

GET /catalog/products
  Parámetros, todos opcionales: q (texto libre o dictado por voz), category,
  brand (marca del repuesto), part_code, moto_brand, moto_model, year,
  store_id, only_in_stock (bool), order_by (relevance|price|price_desc|rating),
  limit (1-100, def. 20), offset (paginación).
  Respuesta:
  {"total":12,"limit":20,"offset":0,
   "items":[{"id":51,"name":"Bujia iridium","category":"electrico",
             "part_code":"BJ-CR8EIX","brand":"NGK","image_url":null,
             "price":46.05,"stock":0,"in_stock":false,"warranty_months":6,
             "store":{"id":4,"business_name":"Autopartes Motupe SAC",
                      "district":"Motupe","distance_km":12.5,
                      "rating_avg":4.3,"rating_count":40,"verified":true}}]}

GET /catalog/products/{id}  -> el mismo objeto del item, más:
  "description": "...",
  "compatibilities":[{"moto_brand":"Honda","moto_model":"XR 150L","year_from":2015,"year_to":2025}],
  "offers":[ ...misma forma que un item... ]   ← MISMO código de parte en OTRAS
  tiendas, ya ordenado por precio y luego por distancia. Esta es la pantalla de
  "comparación de ofertas": muéstralo como lista comparativa con precio, tienda,
  distancia_km, rating y chip "En stock".

GET /catalog/stores/{id} -> datos de la tienda (+ ruc, address, phone, opening_hours)
GET /catalog/stores/{id}/reviews -> [{"rating":5,"comment":"...","created_at":"..."}]

### Pedidos (Bearer, perfil comprador)

POST /orders/checkout -> 201
  {"items":[{"product_id":69,"quantity":1},{"product_id":12,"quantity":2}],
   "delivery_address":"Av. Los Mecanicos 320","payment_method":"yape",
   "notes":"antes de las 6pm"}
  payment_method: "card" | "yape" | "transfer"
  DEVUELVE UNA LISTA: el backend parte el carrito en UNA ORDEN POR PROVEEDOR.
  Si el carrito tiene productos de 3 tiendas, recibes 3 pedidos. La pantalla de
  confirmación debe mostrarlos como pedidos separados, cada uno con su código.
  [{"id":7,"code":"CTR-000007","status":"created",
    "status_label":"Creado (pago pendiente)",
    "next_status":["payment_verified","cancelled"],
    "subtotal":21.7,"shipping_cost":10.0,"total":31.7,
    "payment_method":"yape","payment_op_number":null,"paid_at":null,
    "delivery_address":"Av. Los Mecanicos 320","notes":"antes de las 6pm",
    "created_at":"2026-09-08T00:35:14.484325","updated_at":"...",
    "store":{"id":5,"business_name":"Todo Moto JLO","phone":"979556677",
             "address":"Av. Chinchaysuyo 1580"},
    "items":[{"product_id":69,"product_name":"Filtro de aceite",
              "part_code":"FA-HF112","image_url":null,
              "unit_price":21.7,"quantity":1,"subtotal":21.7}]}]
  Envío: S/ 10.00 por proveedor, gratis desde S/ 250 de subtotal.
  409 si no hay stock: {"detail":"Stock insuficiente de 'Filtro de aceite' (quedan 11)"}

GET   /orders                  -> lista de sus pedidos (si el usuario es proveedor,
                                  devuelve los pedidos de SU tienda). Filtro
                                  opcional ?status_filter=created
GET   /orders/{id}             -> el mismo objeto de arriba
POST  /orders/{id}/payment     -> {"payment_method":"yape","operation_number":"11223344"}
                                  operation_number es opcional (si no lo mandas se
                                  genera uno simulado "SIM..."). Pasa el pedido a
                                  payment_verified. Es el pago SIMULADO de hoy.
PATCH /orders/{id}/status      -> {"status":"preparing"}
GET   /orders/{id}/receipt     -> constancia en JSON (importes como string "31.70")
GET   /orders/{id}/receipt.html-> la MISMA constancia en HTML, lista para imprimir
                                  o guardar como PDF. Ábrela con webview_flutter o
                                  con Printing.layoutPdf. Requiere el header
                                  Authorization, así que si usas WebView pásale el
                                  header; si no, descarga el HTML con http y
                                  muéstralo con Html widget.
POST  /orders/{id}/review      -> {"rating":5,"comment":"Llegó rápido"} (201)
                                  Solo si el pedido está entregado. Cierra el pedido.

### Estados del pedido (para el Stepper/Timeline)

created -> payment_verified -> preparing -> shipped -> delivered -> closed
Desde created, payment_verified y preparing también se puede ir a cancelled
(cancelar devuelve el stock).

Cada respuesta de pedido trae `status` (clave), `status_label` (texto ya en
español, úsalo en la UI) y `next_status` (lista de estados a los que se puede
avanzar AHORA). Construye los botones de acción a partir de `next_status`: si
está vacío, no muestres botones. No hardcodees la máquina de estados en la app.

Quién puede cambiar qué:
- Proveedor: preparing, shipped, cancelled
- Comprador: delivered (confirmar recepción), closed (al calificar), cancelled
Si mandas un cambio no permitido recibes 409 o 403 con el detalle en español.

### Panel del proveedor (Bearer, perfil supplier)

POST /suppliers/store  -> 201  (crea o actualiza su tienda)
  {"business_name":"Repuestos El Motociclista SAC","ruc":"20601234561",
   "address":"Av. Balta 1250","district":"Chiclayo","phone":"979112233",
   "opening_hours":"Lun-Sab 8:00-19:00","logo_url":null,"distance_km":1.2,
   "payment_provider":"simulado","payment_account":null}
  ruc: exactamente 11 dígitos. 409 si el RUC ya está registrado.
GET  /suppliers/store     -> su tienda (404 si todavía no la registró: en ese caso
                             la app debe llevarlo a la pantalla de registro de tienda)
GET  /suppliers/products  -> sus productos
POST /suppliers/products  -> 201
  {"name":"Pastillas de freno delanteras","category":"frenos",
   "part_code":"PF-1120D","brand":"Brembo","description":"...",
   "image_url":"/uploads/products/ab12....jpg","price":55.00,"stock":10,
   "warranty_months":6,"is_active":true,
   "compatibilities":[{"moto_brand":"Bajaj","moto_model":"Pulsar NS 200",
                       "year_from":2015,"year_to":2025}]}
PUT    /suppliers/products/{id} -> mismo cuerpo (reemplaza también las compatibilidades)
DELETE /suppliers/products/{id} -> 204 (baja lógica)

### Imágenes

POST /uploads/image  (Bearer, multipart/form-data, campo "file")
  jpg/jpeg/png/webp, máximo 5 MB.
  -> 201 {"path":"/uploads/products/ab12...jpg","url":"http://127.0.0.1:8000/uploads/products/ab12...jpg"}
  Guarda `path` en el producto y arma la URL completa en la app concatenando la
  base URL (así la imagen sigue funcionando si cambias de servidor). El campo
  image_url de los productos puede venir null: usa un placeholder.

## Lo que tienes que hacer en el proyecto Flutter

1. Capa de red, en lib/core/network/:
   - ApiClient sobre `dio` con baseUrl desde --dart-define, un interceptor que
     agregue el Bearer y otro que capture 401 -> borrar token y volver al login.
   - Un ApiException que traduzca el {"detail": ...} a un mensaje mostrable.
2. Modelos: elimina los modelos mock y genera los del contrato de arriba
   (User, Store, Product, Compatibility, Order, OrderItem) con fromJson/toJson.
   Deja fuera cualquier campo que no esté en el contrato.
3. Repositorios por feature: AuthRepository, CatalogRepository,
   SupplierRepository, OrderRepository. Nada de llamadas HTTP dentro de widgets.
4. Estado: usa BLoC/Cubit si el proyecto ya lo tiene; si no, Riverpod. No mezcles
   dos soluciones de estado en el mismo proyecto.
5. Reemplaza TODOS los datos dummy de las pantallas existentes por datos del
   backend, con estado de carga (shimmer o CircularProgressIndicator), estado
   vacío ("No encontramos repuestos para esa moto") y estado de error con botón
   de reintentar.
6. Pantallas a conectar, en este orden:
   a. Login / registro (con selector de perfil comprador o proveedor)
   b. Buscador: filtros en cascada + búsqueda por texto y por dictado de voz
      (speech_to_text ya integrado: el texto reconocido va tal cual en `q`)
   c. Ficha de producto con la lista de ofertas de otras tiendas
   d. Carrito local agrupado por proveedor + checkout (recuerda: devuelve varios
      pedidos) + pantalla de pago simulado que llama a /orders/{id}/payment
   e. Seguimiento del pedido: Stepper construido con status/next_status
   f. Constancia de pago (receipt.html)
   g. Calificación al cerrar el pedido
   h. Panel del proveedor: registrar tienda, publicar/editar repuesto con subida
      de imagen (image_picker + multipart) y bandeja de pedidos de su tienda
7. Guarda el token con flutter_secure_storage y verifica la sesión al abrir la
   app llamando a /auth/me (si falla, al login).
8. Permisos en android/app/src/main/AndroidManifest.xml:
   <uses-permission android:name="android.permission.INTERNET"/>
   y android:usesCleartextTraffic="true" en <application> (solo para desarrollo).

## Cuentas de prueba (ya cargadas en la base)

Contraseña de todas: 123456
- Compradores: taller.julio@demo.pe, carlos.vasquez@demo.pe, motosexpress@demo.pe
- Proveedores: proveedor1@demo.pe ... proveedor5@demo.pe

## Entregables

1. Lista de paquetes a agregar en pubspec.yaml, con versión.
2. El código de la capa de red y los modelos.
3. Las pantallas conectadas, una por una, indicando qué archivo modificaste.
4. Al final, los pasos exactos para probar el flujo completo: login como
   comprador, buscar por Honda XR 150L, comparar ofertas, agregar al carrito,
   pagar, ver el pedido en seguimiento, y luego entrar como proveedor1@demo.pe
   para ver ese mismo pedido en su bandeja y despacharlo.

Empieza por la capa de red y el login. Ve pantalla por pantalla, no todo de golpe.
````

---

## 3. Configuración de red en el proyecto Flutter

Esto lo haces tú (o lo verificas después de que Claude lo haga).

### `android/app/src/main/AndroidManifest.xml`

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="ChapaTuRepuesto"
        android:usesCleartextTraffic="true"   <!-- solo desarrollo: la API es HTTP -->
        ...>
```

Sin `usesCleartextTraffic` Android 9+ bloquea el HTTP sin dar error claro: la app
simplemente falla la conexión. Es el error más común al conectar con un backend
local. **Quítalo cuando publiques con HTTPS.**

### URL configurable

```dart
// lib/core/network/api_config.dart
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // emulador -> PC anfitrión
  );
}
```

Para correr en un celular físico:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.45:8000
```

En Android Studio la misma bandera va en *Run > Edit Configurations > Additional
run args*.

### Paquetes que probablemente falten en `pubspec.yaml`

```yaml
dependencies:
  dio: ^5.7.0                    # cliente HTTP con interceptores
  flutter_secure_storage: ^9.2.2 # guardar el JWT
  intl: ^0.19.0                  # formato de moneda y fechas
  image_picker: ^1.1.2           # foto del repuesto (proveedor)
  speech_to_text: ^7.0.0         # dictado de voz en el buscador
  webview_flutter: ^4.10.0       # ver la constancia de pago
  cached_network_image: ^3.4.1   # imágenes del catálogo
```

Ajusta las versiones a las que resuelva `flutter pub get` con tu SDK.

### El detalle que rompe el login

`/auth/login` es el único endpoint con formato de formulario:

```dart
final res = await dio.post(
  '/auth/login',
  data: {'username': email, 'password': password},   // username = el correo
  options: Options(contentType: Headers.formUrlEncodedContentType),
);
final token = res.data['access_token'];
```

Si lo mandas como JSON el servidor responde **422**, no 401.

### Subir la imagen de un repuesto

```dart
final form = FormData.fromMap({
  'file': await MultipartFile.fromFile(archivo.path, filename: 'repuesto.jpg'),
});
final res = await dio.post('/uploads/image', data: form);  // con Bearer
final path = res.data['path'];   // "/uploads/products/ab12....jpg"
// guarda `path` en el producto; para mostrarla: ApiConfig.baseUrl + path
```

---

## 4. Verificar que los movimientos quedan guardados en MySQL

El objetivo es ver, en HeidiSQL, la fila que creó la app.

1. Enciende MySQL en Laragon y ejecuta `.\ctr reset` (base limpia con demo).
2. `.\ctr lan` y deja el servidor corriendo. Cada petición aparece en la consola.
3. En la app: entra como `taller.julio@demo.pe` / `123456`, busca un repuesto,
   agrégalo al carrito y paga.
4. En HeidiSQL, base `chapaturepuesto`:

```sql
SELECT code, status, total, payment_op_number, created_at
FROM orders ORDER BY id DESC LIMIT 5;

SELECT * FROM order_items WHERE order_id = (SELECT MAX(id) FROM orders);

-- el stock del producto comprado bajó:
SELECT id, name, stock FROM products WHERE id = <product_id>;
```

Si ves ahí el pedido `CTR-0000xx` que acabas de crear desde el celular, la
cadena completa app -> API -> MySQL está funcionando.

5. Entra ahora como `proveedor1@demo.pe`: en su bandeja debe aparecer ese mismo
   pedido, y al despacharlo la columna `status` cambia en la base.

### Cuando quieras empezar de cero

```powershell
.\ctr reset    # borra todo y recarga los datos simulados
.\ctr empty    # borra todo y NO carga nada (para trabajar con datos reales)
```

---

## 5. Lo que todavía no existe en el backend

Para que no lo busques ni lo inventes en la app:

| Falta | Cuándo hará falta | Dónde está explicado |
|---|---|---|
| Pago real (Mercado Pago / Niubiz) | Al cobrar dinero de verdad | `docs/INTEGRACIONES.md` §1 |
| Login con Google funcionando | Falta `GOOGLE_CLIENT_ID` en `.env` | `docs/INTEGRACIONES.md` §2 |
| Yape con confirmación automática | Requiere pasarela o convenio BCP | `docs/INTEGRACIONES.md` §3 |
| Boleta/factura electrónica SUNAT | Antes de la primera venta real | `docs/INTEGRACIONES.md` §4 |
| Notificaciones push | Hoy los avisos son correo (y en modo simulado solo se escriben en el log) | `app/notify.py` |
| Recuperación de contraseña por correo | Cuando haya usuarios reales | — |
| Carrito guardado en el servidor | Solo si quieres el carrito sincronizado entre dispositivos | — |

Todo lo demás del informe (catálogo, compatibilidad, comparación de ofertas,
carrito por proveedor, pedidos, estados, constancia, calificaciones, subida de
imágenes) ya está implementado y probado.
