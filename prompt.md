Actúa como un desarrollador Senior en Flutter y Dart especializado en arquitecturas limpias para aplicaciones móviles de tipo Marketplace B2B/B2C.

Necesito que construyas la estructura de código base y el prototipo funcional en Flutter para una aplicación llamada "ChapaTuRepuesto".

### CONTEXTO DEL PROYECTO
ChapaTuRepuesto es una aplicación móvil marketplace que conecta talleres mecánicos independientes de motocicletas y motociclistas finales con distribuidores de autopartes y repuestos.

1. Problema Principal: Los mecánicos pierden tiempo de trabajo al desplazarse a tiendas físicas para cotizar repuestos, mientras que el motociclista sufre demoras e incertidumbre en el tiempo de reparación.
2. Solución: Transformar el smartphone del mecánico en un mostrador digital en tiempo real con catálogo por compatibilidad (marca, modelo, año), búsqueda por dictado de voz y código de parte, comparación de precios/proveedores y pasarela de pago.
3. Perfiles de usuario:
    - Comprador (Mecánico / Motociclista)
    - Proveedor (Tienda de autopartes con RUC verificado)

### REQUISITOS TÉCNICOS Y ARQUITECTURA
- Lenguaje/Framework: Dart & Flutter (SDK v3.x+)
- Arquitectura: Clean Architecture + Feature-First (Separación clara entre presentation, domain, data).
- Gestión de Estado: BLoC / Cubit o Provider/Riverpod (especifica la recomendación en la respuesta).
- Estilos UI: Material Design 3 con un Tema Oscuro/Claro personalizado (Color principal: Azul profesional #1A365D, Acento: Naranja mecánico/Ámbar #F59E0B).

### MÓDULOS Y PANTALLAS A DESARROLLAR EN CÓDIGO
Por favor genera el código limpio, bien documentado y modularizado de los siguientes módulos:

1. Estructura de Proyecto (Folder Tree):
    - Muestra la organización completa del proyecto en `lib/` aplicando Clean Architecture.

2. Modelos de Datos (`Data Models`):
    - `User` (id, name, email, role: buyer/seller, RUC).
    - `Product` (id, name, category, partCode, brand, compatibleModels: List<Compatibility>, imageUrl, price, stock, supplierId).
    - `Compatibility` (brand, model, yearRange).
    - `Order` (id, buyerId, supplierId, orderCode, status: pending/verified/shipping/delivered, total, createdAt).

3. Buscador por Compatibilidad y Dictado de Voz (Pantalla Principal de Comprador):
    - Widget con barra de búsqueda con botón de micrófono (integración simulated speech-to-text).
    - Filtros en cascada por Marca, Modelo y Año de la motocicleta.
    - GridView de productos recomendados con su respectivo chip de "En Stock" y compatibilidad garantizada.

4. Ficha de Producto y Comparación de Ofertas:
    - Vista detallada del repuesto mostrando especificaciones técnicas, compatibilidad comprobada y lista de proveedores que ofrecen la misma pieza ordenados por precio/distancia.

5. Carrito de Compras y Checkout:
    - Pantalla que agrupa los productos por proveedor (ya que la orden se procesa individualmente por tienda) con resumen de pago y selector de pasarela de tarjeta/Yape/BCP.

6. Tracking de Pedido (Seguimiento en Tiempo Real):
    - Pantalla con Stepper/Timeline mostrando los estados de la orden: [Creado -> Pago Verificado -> En Preparación -> Despachado -> Entregado].

### ENTREGABLES ESPERADOS
1. Árbol de directorios completo del proyecto.
2. Archivo `main.dart` con la configuración de rutas, temas y dependencias iniciales.
3. Código completo y ejecutable de las pantallas clave especificadas (utiliza widgets modularizados y datos mockeados/dummy bien estructurados).
4. Indicaciones breves de qué paquetes adicionales instalar en `pubspec.yaml` (ej. speech_to_text, flutter_bloc, intl, etc.).