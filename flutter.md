# Instalación manual de Flutter para ChapaTuRepuesto

Guía escrita **para esta PC concretamente** (Windows 11, Android Studio
2025.3.3 ya instalado en `C:\Program Files\Android\Android Studio`).

## Diagnóstico: por qué no te deja ejecutar el proyecto

| Qué revisé | Estado | Consecuencia |
|---|---|---|
| `flutter` / `dart` en el PATH | **NO existe** | `flutter run` no es un comando: nada arranca |
| Android SDK (`%LOCALAPPDATA%\Android\Sdk`) | OK (platforms 36 y 36.1, build-tools 35→37) | — |
| `cmdline-tools` del SDK | **falta** | `flutter doctor --android-licenses` falla |
| `java` del PATH | **23.0.2 (Oracle)** | Gradle 9.3.1 revienta o avisa; hay que usar el JDK 21 de Android Studio |
| JBR de Android Studio | OK, **JDK 21** en `...\Android Studio\jbr` | es el JDK correcto para este proyecto |
| `android\local.properties` | **falta** (está en .gitignore) | `settings.gradle.kts` aborta con *"flutter.sdk not set"* |

O sea: el problema no es el proyecto, es que **falta el SDK de Flutter**. Lo
demás son tres ajustes de configuración.

Versión que necesita este proyecto: **Flutter 3.47.2 stable / Dart 3.13.2**
(`pubspec.yaml` pide `sdk: ^3.13.2`, y `.metadata` fue generado con el commit
`d3b14c87` que es exactamente ese release). No uses una versión anterior: el
`android/settings.gradle.kts` usa AGP 9.1.0 + Gradle 9.3.1, que solo trae el
template de Flutter reciente.

---

## 1. Instalar el SDK de Flutter

### Opción A — ZIP (la más rápida)

1. Descarga
   `https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.2-stable.zip`
2. Descomprime en **`D:\flutter`** (que quede `D:\flutter\bin\flutter.bat`).

   > No lo pongas en `C:\Program Files\` ni en ninguna ruta con espacios ni que
   > pida permisos de administrador: el SDK se auto-actualiza y falla si no
   > puede escribir en su propia carpeta.

### Opción B — git (permite `flutter upgrade`/`downgrade`)

```powershell
git clone -b stable https://github.com/flutter/flutter.git D:\flutter
cd D:\flutter
git checkout 3.47.2
```

---

## 2. Agregar Flutter al PATH (permanente)

**Interfaz gráfica:** menú Inicio → *"Editar las variables de entorno de la
cuenta"* → `Path` → *Nuevo* → `D:\flutter\bin` → Aceptar.

**O en PowerShell (una sola línea, sin admin):**

```powershell
[Environment]::SetEnvironmentVariable(
  'Path',
  [Environment]::GetEnvironmentVariable('Path','User') + ';D:\flutter\bin',
  'User')
```

**Cierra y vuelve a abrir la terminal** (y Android Studio) para que tome el
cambio. Comprueba:

```powershell
flutter --version     # Flutter 3.47.2 ... Dart 3.13.2
```

---

## 3. Apuntar Gradle al JDK 21 de Android Studio

Tu `java` del PATH es el **23**, y Gradle 9.3.1 no lo soporta bien. Android
Studio trae un JDK 21 embebido; dile a Flutter que use ese:

```powershell
flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
```

Ese ajuste queda guardado en `%APPDATA%\flutter\settings` y solo afecta a las
builds de Flutter — tu Java 23 del sistema no se toca.

> Si prefieres una variable de entorno, es `JAVA_HOME =
> C:\Program Files\Android\Android Studio\jbr` (Gradle la respeta).
> **No** apuntes a `C:\Program Files\Android\jdk\jdk-8.0.302.8-hotspot`: es un
> JDK 8 residual de una instalación vieja y no sirve para AGP 9.

---

## 4. Completar el Android SDK

Falta `cmdline-tools`, sin él no puedes aceptar las licencias:

Android Studio → **More Actions ▸ SDK Manager ▸ pestaña SDK Tools** → marca
**Android SDK Command-line Tools (latest)** → Apply.

Después, en la terminal:

```powershell
flutter doctor --android-licenses     # responde "y" a todo
flutter doctor -v
```

Debe quedar `[√] Android toolchain`. Los `[!]` de Visual Studio (desarrollo
Windows) y Xcode puedes ignorarlos: esta app va a Android.

---

## 5. `android\local.properties`

Este archivo está en `.gitignore`, así que **no viene en el repo** y sin él el
build de Android falla con `flutter.sdk not set in local.properties`.
Normalmente lo genera `flutter pub get`; si no aparece, créalo a mano en
`D:\Chapaturepuesto_GENERAL\android\local.properties`:

```properties
sdk.dir=C:\\Users\\Ryzen7\\AppData\\Local\\Android\\Sdk
flutter.sdk=D:\\flutter
```

Ojo: **barras dobles**, es un `.properties` de Java.

---

## 6. Preparar el proyecto

```powershell
cd D:\Chapaturepuesto_GENERAL
flutter pub get
flutter analyze          # debe salir "No issues found!"
flutter test             # los checks del carrito, contrato del API y fechas
```

> La **primera** `flutter run` / `flutter build apk` tarda bastante: Gradle baja
> AGP, sus dependencias y el NDK (~1 GB en total) y se queda un buen rato en
> `Preparing "Install NDK (Side by side)..."`. No está colgado. Las siguientes
> builds son de segundos.

Si `flutter pub get` se queda colgado detrás de un proxy o del antivirus,
`flutter pub get --verbose` te dice en qué paquete se traba.

---

## 7. Elegir dispositivo y ejecutar

```powershell
flutter devices
```

### Emulador

Android Studio → **Device Manager** → crea un dispositivo con imagen
**API 36** (ya tienes `system-images/android-36.1` descargada) → *Play*.

Con el emulador arriba, la URL del backend es **siempre** `http://10.0.2.2:8000`
(así ve el emulador a tu PC). Ese es el valor por defecto de la app:

```powershell
flutter run
```

### Celular físico por USB

1. En el celular: *Ajustes ▸ Acerca del teléfono* → toca 7 veces *Número de
   compilación* → vuelve a *Opciones de desarrollador* → activa **Depuración
   por USB**.
2. Conecta el cable y acepta el diálogo *"¿Permitir depuración USB?"*.
3. Comprueba: `flutter devices` (o
   `C:\Users\Ryzen7\AppData\Local\Android\Sdk\platform-tools\adb.exe devices`).
4. El celular **no** entiende `10.0.2.2`: hay que pasarle la IP de tu PC en la
   WiFi (la que imprime `.\ctr lan` en el backend):

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.45:8000
```

En Android Studio la misma bandera va en
**Run ▸ Edit Configurations ▸ Additional run args**.

> Si el celular no conecta con el backend pero el emulador sí, es el **Firewall
> de Windows**: permite `python.exe` en *redes privadas*. Verifica primero
> abriendo `http://TU_IP:8000/health` en el navegador del celular; debe
> responder `{"status":"ok"}`.

---

## 8. Errores frecuentes y su causa real

| Mensaje | Causa | Arreglo |
|---|---|---|
| `flutter no se reconoce como un comando` | PATH no aplicado | Paso 2 + **reabrir la terminal** |
| `flutter.sdk not set in local.properties` | falta el archivo | Paso 5 |
| `Unsupported class file major version` / Gradle cae al arrancar | está usando el Java 23 | Paso 3 |
| `Android license status unknown` | falta `cmdline-tools` | Paso 4 |
| `this and base files have different roots: C:\...\Pub\Cache\... y D:\Chapaturepuesto_GENERAL\android` | el pub cache está en `C:` y el proyecto en `D:`; el compilador incremental de Kotlin no sabe calcular rutas entre unidades | ya está resuelto: `kotlin.incremental=false` en `android/gradle.properties` (ver 8.b) |
| `Could not resolve com.android.application:9.1.0` | primera build sin internet | conéctate; Gradle descarga ~500 MB la primera vez |
| La primera build se queda minutos en `Preparing "Install NDK..."` | Gradle está bajando el NDK (~1 GB) | no es un cuelgue: déjalo terminar. Solo pasa una vez |
| La app abre pero toda petición falla, sin error claro | Android 9+ bloquea HTTP plano | ya está resuelto: `android:usesCleartextTraffic="true"` en el `AndroidManifest.xml` |
| `Connection refused` en el emulador | usaste `127.0.0.1` | en el emulador la PC es `10.0.2.2` |
| Build lento y luego OOM | `org.gradle.jvmargs=-Xmx8G` en `android/gradle.properties` | si tienes menos de 16 GB de RAM, bájalo a `-Xmx4G` |

---

## 8.b El proyecto está en D: y el pub cache en C:

Es tu caso, y rompe la build de una forma que no se entiende sola:

```
java.lang.IllegalArgumentException: this and base files have different roots:
  C:\Users\Ryzen7\AppData\Local\Pub\Cache\hosted\pub.dev\speech_to_text-7.4.0\...
  y D:\Chapaturepuesto_GENERAL\android
```

El compilador incremental de Kotlin guarda las rutas de los fuentes
**relativas** al módulo. Entre `C:` y `D:` no existe ruta relativa, así que al
cerrar sus cachés lanza esa excepción y la build muere. Solo afecta a los
plugins que traen código Kotlin: `speech_to_text` e `image_picker_android`.

Ya está arreglado en el repo con una línea en `android/gradle.properties`:

```properties
kotlin.incremental=false
```

Cuesta unos segundos por build de plugin (que casi nunca cambian). Si algún día
quieres recuperar la compilación incremental, pon el pub cache en la misma
unidad que el proyecto y borra esa línea:

```powershell
[Environment]::SetEnvironmentVariable('PUB_CACHE','D:\pub-cache','User')
# reabre la terminal y vuelve a correr flutter pub get (se redescarga todo)
```

---

## 9. Resumen ejecutable

```powershell
# (una sola vez)
#  - descomprimir el zip en D:\flutter
[Environment]::SetEnvironmentVariable('Path',
  [Environment]::GetEnvironmentVariable('Path','User') + ';D:\flutter\bin','User')
# --- reabrir la terminal aquí ---
flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
flutter doctor --android-licenses
flutter doctor -v

# (cada vez que trabajes)
cd D:\Chapaturepuesto_BACKEND ; .\ctr lan      # backend arriba, anota la IP
cd D:\Chapaturepuesto_GENERAL ; flutter pub get ; flutter run
```
