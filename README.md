# Login animado con Rive, Firebase Authentication y productos desde Spring Boot

Aplicación Flutter que muestra un login animado con Rive, autentica al usuario con
Firebase Authentication y, después del acceso, consulta un backend Spring Boot que
obtiene los productos desde PostgreSQL.

Repositorio: <https://github.com/Dave2826/rive-login-experience>

---

## 1. Objetivo de la actividad

Integrar en una sola aplicación Flutter:

- Una pantalla de login con una animación interactiva creada en Rive.
- Autenticación real de usuarios con Firebase Authentication (correo y contraseña).
- Validación local del formato de correo y contraseña antes de llamar a Firebase.
- Consulta de productos a un backend Spring Boot propio, que los obtiene de PostgreSQL.
- Una pantalla final que muestra la lista de productos con estados de carga, error y
  opción de reintentar.

El resultado es un flujo completo: **login animado → autenticación → productos**.

---

## 2. Tecnologías utilizadas

### Aplicación Flutter

| Tecnología | Versión verificada |
|---|---|
| Flutter (stable) | 3.47.6 |
| Dart | 3.13.5 |
| `rive` | 0.13.20 |
| `firebase_core` | 5.2.0 |
| `firebase_auth` | 7.1.0 |
| `http` | 1.6.0 |
| `flutter_lints` | 6.0.0 |

### Backend (repositorio independiente)

| Tecnología | Versión verificada |
|---|---|
| Spring Boot | 3.5.14 |
| Java (toolchain) | 21 |
| Gradle Wrapper | incluido en el repositorio |
| PostgreSQL (driver JDBC) | 42.7.3 |
| springdoc-openapi | 2.8.16 |

### Servicios

| Servicio | Uso |
|---|---|
| Firebase Authentication | Validación de credenciales (Email/Password) |
| PostgreSQL | Base de datos de productos |
| Android Emulator | Entorno de ejecución verificado |

---

## 3. Arquitectura y flujo general

```
┌──────────────────────────┐
│  Flutter (Android)       │
│  1. Login animado (Rive) │
└────────────┬─────────────┘
             │ correo + contraseña
             ▼
┌──────────────────────────┐
│  Firebase Authentication │
│  2. Valida credenciales  │
└────────────┬─────────────┘
             │ sesión válida
             ▼
┌──────────────────────────┐        ┌──────────────────────┐
│  Flutter                 │ ─────► │  Spring Boot :8080   │
│  3. GET /products        │        │  4. Consulta la BD   │
└────────────┬─────────────┘        └──────────┬───────────┘
             │                                 │
             │                                 ▼
             │                      ┌──────────────────────┐
             │                      │  PostgreSQL          │
             │                      └──────────────────────┘
             ▼
┌──────────────────────────┐
│  5. Lista de productos   │
│     en pantalla          │
└──────────────────────────┘
```

### Paso a paso

1. **Flutter muestra el login animado con Rive.** El oso reacciona al usuario:
   sigue la escritura del correo, se tapa los ojos mientras se escribe la
   contraseña y reacciona al pulsar *Login*.
2. **Firebase Authentication valida las credenciales** mediante
   `signInWithEmailAndPassword`.
3. **Después del acceso exitoso, Flutter consulta Spring Boot** con una petición
   `GET /products`.
4. **Spring Boot obtiene los productos de PostgreSQL** y los devuelve en formato JSON.
5. **Flutter presenta la lista de productos** en una pantalla con estados de carga,
   error (con botón *Reintentar*), lista vacía y lista con datos.

### Comportamiento de la pantalla de login

- Validación local del correo y de la contraseña antes de contactar a Firebase.
- Si el formato no es válido, los mensajes aparecen bajo el campo correspondiente y
  el oso muestra su animación de error, sin llamar a Firebase.
- Si Firebase rechaza las credenciales, el mensaje aparece bajo el campo que
  corresponda y el oso también muestra la animación de error.
- Si el acceso es correcto, el oso celebra durante unos 2 segundos y luego la
  aplicación navega a la pantalla de productos.
- Mientras se procesa el intento, el botón muestra un indicador de carga y se
  bloquean los envíos duplicados.

---

## 4. Estructura del proyecto

```
lib/
├── main.dart                     # Arranque e inicialización de Firebase
├── firebase_options.dart         # Configuración generada por FlutterFire
├── screens/
│   ├── login_screen.dart         # Login + animación Rive + Firebase Auth
│   └── products_screen.dart      # Lista de productos, error y reintento
└── services/
    └── product_service.dart      # Consumo de GET /products

assets/
└── login-bear-animation.riv      # Animación Rive del oso

evidencias/                       # Capturas de funcionamiento
android/ios/web/...               # Plataformas generadas por Flutter
```

---

## 5. Requisitos previos

- **Flutter 3.47.6** con Dart 3.13.5 (el proyecto declara `sdk: ^3.13.5`).
- **Android Studio / Android SDK** con un emulador o dispositivo Android disponible.
- **JDK 21** para ejecutar el backend (el backend lo fija con el *toolchain* de Gradle).
- **PostgreSQL** en ejecución con la base de datos de productos del backend.
- **Repositorio del backend** disponible en local: `market-backend-2026-3-a`.
- Proyecto de **Firebase** con autenticación por correo habilitada (ya configurado en
  este repositorio).

---

## 6. Configuración de Firebase

El proyecto ya está configurado; no hace falta crear nada nuevo para ejecutarlo.

| Dato | Valor |
|---|---|
| Proyecto de Firebase | `flutter-spring-test-73f45` |
| Aplicación Android | `com.example.login_drive_animation` |
| Método de acceso | Correo electrónico y contraseña (Email/Password) |

Archivos de configuración incluidos en el repositorio:

| Archivo | Función |
|---|---|
| `android/app/google-services.json` | Vincula la app Android con el proyecto de Firebase |
| `lib/firebase_options.dart` | Opciones de Firebase generadas por FlutterFire |
| `firebase.json` | Configuración de FlutterFire para este proyecto |

Además, el módulo Android tiene aplicado el plugin de Gradle
`com.google.gms.google-services`, necesario para procesar `google-services.json`.

La inicialización se realiza una sola vez en `lib/main.dart`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

> **Nota de seguridad:** en este documento no se incluyen contraseñas ni claves
> privadas. Las claves de cliente de Firebase que aparecen en
> `lib/firebase_options.dart` son identificadores públicos de la aplicación, no
> credenciales de usuario.

Para crear usuarios de prueba, usa la sección **Authentication → Users** de la consola
de Firebase, con el método Email/Password habilitado.

---

## 7. Configuración y ejecución del backend

El backend es un proyecto **independiente** (no forma parte de este repositorio):

- Ruta local utilizada: `C:\dev\market-backend-2026-3-a`
- Puerto por defecto: **8080**
- Endpoint consumido por la app: **`GET /products`**

### 7.1 Base de datos

El backend lee su conexión de variables de entorno (con valores por defecto en
`src/main/resources/application.yml`):

| Variable | Descripción |
|---|---|
| `DB_URL` | URL JDBC de PostgreSQL (por defecto `localhost:5432`, base `market-app-26-2`) |
| `DB_USERNAME` | Usuario de la base de datos |
| `DB_PASSWORD` | Contraseña de la base de datos |
| `SERVER_PORT` | Puerto del servidor (por defecto `8080`) |

La base de datos debe existir previamente con sus tablas y datos: la configuración usa
`ddl-auto: none`, por lo que Hibernate **no** crea el esquema automáticamente.

### 7.2 Arranque

Desde la carpeta del backend:

```powershell
# Windows
.\gradlew.bat bootRun
```

```bash
# macOS / Linux
./gradlew bootRun
```

El servicio queda disponible en `http://localhost:8080`.

### 7.3 Verificación del endpoint

```bash
curl http://localhost:8080/products
```

Respuesta esperada (lista JSON):

```json
[
  {
    "productId": 1,
    "name": "Guayaba",
    "categoryId": 1,
    "price": 300.0,
    "stock": 500,
    "active": true,
    "category": {
      "categoryId": 1,
      "name": "Frutas y verduras",
      "active": true
    }
  }
]
```

El proyecto incluye springdoc, por lo que la documentación interactiva de la API queda
disponible en la ruta por defecto `/swagger-ui/index.html` del servidor.

> El backend **no** se modifica desde este repositorio; solo se consume su endpoint.

---

## 8. Instalación de dependencias Flutter

En la raíz de este proyecto:

```bash
flutter pub get
```

---

## 9. Ejecución en Android Emulator

1. Arranca el backend (sección 7) y confirma que responde en `http://localhost:8080/products`.
2. Inicia el emulador Android.
3. Comprueba que Flutter lo detecta:

   ```bash
   flutter devices
   ```

4. Ejecuta la aplicación:

   ```bash
   flutter run
   ```

5. En la app, introduce un correo y una contraseña válidos registrados en Firebase.
   Tras la animación de éxito se abrirá la lista de productos.

Compilación de un APK de depuración (opcional):

```bash
flutter build apk --debug
```

El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 10. Configuración alternativa de `API_BASE_URL`

La URL del backend se define en tiempo de compilación y por defecto es
`http://10.0.2.2:8080` (la dirección con la que el emulador Android alcanza el equipo
anfitrión).

Si el backend se ejecuta en otra máquina o en otro puerto, se puede sobrescribir sin
tocar el código:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

También se puede aplicar a una compilación:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

El valor se lee en `lib/services/product_service.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
```

El endpoint consultado siempre es `GET {API_BASE_URL}/products`.

---

## 11. Evidencias de funcionamiento

Carpeta `evidencias/`:

| Archivo | Qué muestra |
|---|---|
| `01-api-products.png` | Respuesta JSON de `GET /products` del backend en `localhost:8080` |
| `02-login-screen.png` | Pantalla de login con el oso Rive y las credenciales capturadas |
| `03-login-error.png` | Credenciales incorrectas: mensaje bajo el campo y animación de error del oso |
| `04-login-success.png` | Autenticación correcta: animación de éxito del oso |
| `05-products-screen.png` | Pantalla de productos con la lista obtenida del backend |

---

## 12. Nota sobre `10.0.2.2`

El emulador Android se ejecuta en una red virtual: `localhost` dentro del emulador es
el propio emulador, no el equipo donde corre el backend. Por eso la app usa
`10.0.2.2`, que es la dirección especial con la que el emulador accede al equipo
anfitrión.

- **Emulador Android + backend en la misma máquina:** `http://10.0.2.2:8080` (valor por defecto).
- **Dispositivo físico:** usa la IP de tu equipo en la red local, por ejemplo
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`.
- **HTTP sin TLS:** la app declara `android:usesCleartextTraffic="true"` y el permiso
  `INTERNET` en `AndroidManifest.xml`, necesarios para consumir el backend local por
  HTTP. En un entorno de producción se debería usar HTTPS.

---

## Notas finales

- Proyecto desarrollado como actividad académica (Tec de Monterrey – TecDesoftware).
- El backend y PostgreSQL se mantienen en un repositorio y una base de datos
  independientes de esta aplicación.
