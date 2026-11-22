# Login animado con Rive, autenticación JWT y sesión persistente

Aplicación Flutter con un login animado creado en Rive que se autentica contra un
backend Spring Boot propio mediante JWT, guarda el token en almacenamiento seguro,
restaura la sesión entre reinicios y, tras el acceso, muestra el catálogo de platillos
obtenido de PostgreSQL.

Repositorio de la aplicación: <https://github.com/Dave2826/rive-login-experience>

Backend (repositorio independiente): <https://github.com/Dave2826/restaurant-api-springboot>

---

## 1. Objetivo

Integrar en una sola aplicación Flutter:

- Una pantalla de login con una animación interactiva creada en Rive.
- Autenticación real contra un backend Spring Boot que valida usuario y contraseña y
  emite un token JWT.
- Uso del token JWT como credencial `Bearer` para consumir el catálogo protegido.
- Persistencia cifrada del token, restauración automática de la sesión al abrir la app
  y cierre de sesión manual.
- Invalidación de la sesión cuando el backend responde `401`, con regreso controlado al
  login.
- Una pantalla que lista los platillos obtenidos de PostgreSQL, con estados de carga,
  error con reintento, lista vacía y lista con datos.

Flujo resultante: **login animado → `POST /auth/login` → JWT → almacenamiento seguro →
`GET /api/platillos` → catálogo**, con restauración del token en arranques posteriores.

---

## 2. Tecnologías

### Aplicación Flutter

| Tecnología | Versión (verificada con `pubspec.lock` / `flutter --version`) |
|---|---|
| Flutter (stable) | 3.47.6 |
| Dart | 3.13.5 (`sdk: ^3.13.5`) |
| `http` | 1.6.0 |
| `rive` | 0.13.20 |
| `flutter_secure_storage` | 11.2.0 |
| `flutter_lints` | 6.0.0 |
| `flutter_test` (dev) | SDK de Flutter |
| Paquete | `login_drive_animation` |

`flutter_secure_storage` guarda el JWT con el Keystore de Android, el Keychain en
iOS/macOS y el almacén de credenciales del sistema en escritorio. No requiere cambios en
Gradle: el proyecto usa `minSdk = flutter.minSdkVersion` (24) y el plugin exige 23.

### Backend (repositorio independiente)

| Tecnología | Versión |
|---|---|
| Spring Boot | 3.4.1 |
| Java (toolchain de Gradle) | 21 |
| Spring Security + JWT | `jjwt` 0.12.6 (HS256) |
| springdoc-openapi | 2.8.6 |
| MapStruct | 1.6.3 |
| PostgreSQL | base `restaurant_db` en `localhost:5432` |
| Puerto del servidor | 8080 |

---

## 3. Flujo de autenticación y sesión

```
Login manual
  POST /auth/login  {"username","password"}
        │ 200 {"token":"..."}
        ▼
SessionController.startSession(token)
        │
        ├── SecureTokenStorage  (Keystore / Keychain)
        └── estado authenticated ──► SessionGate ──► ProductsScreen
                                                      GET /api/platillos
                                                      Authorization: Bearer <token>

Arranque de la app
  SessionController.restore()
        ├── sin token ─────────────► unauthenticated ──► LoginScreen
        ├── token vigente ─────────► authenticated   ──► ProductsScreen
        └── token expirado/inválido ► borrar + aviso ──► LoginScreen

Respuesta 401 del catálogo
  ProductService ──► UnauthorizedException
        └── ProductsScreen ──► SessionController.expireSession()
                                borrar token + aviso ──► LoginScreen
```

### 3.1 Comportamiento del login

1. El oso de Rive sigue la escritura del usuario, se tapa los ojos mientras se escribe
   la contraseña y reacciona al pulsar **Login**.
2. Validación local antes de llamar al backend: si el usuario o la contraseña están
   vacíos se muestra `Ingresa tu usuario` / `Ingresa tu contraseña` bajo el campo
   correspondiente y el oso reproduce la animación de fallo. No se envía ninguna
   petición.
3. Si ambos campos tienen contenido, se ejecuta `POST /auth/login`.
4. Con credenciales correctas se apaga el indicador de carga, el oso celebra y, tras unos
   2 segundos, el token se entrega a `SessionController.startSession`, que lo guarda y
   cambia el estado a `authenticated`. `SessionGate` muestra entonces el catálogo; el
   login ya no navega por su cuenta.
5. Mientras se procesa el intento, el botón muestra un indicador circular y se bloquean
   los envíos duplicados.

### 3.2 Restauración de sesión

- Al arrancar, `SessionGate` llama una sola vez a `SessionController.restore()` y muestra
  un indicador breve mientras se lee el almacén seguro.
- **Sin token guardado:** estado `unauthenticated` y login en reposo, sin mensajes.
- **Token vigente:** estado `authenticated`; se abre el catálogo directamente. La primera
  petición real es la que confirma ante el servidor que el token sigue siendo válido.
- **Token expirado, malformado o sin `exp`:** se borra del almacén, se deja el aviso
  `Tu sesión expiró o ya no es válida. Inicia sesión de nuevo.` y se muestra el login.
- **Fallo al leer el almacén:** la sesión se considera cerrada (fail-closed) sin lanzar
  excepciones; el usuario vuelve al login.

### 3.3 Validación local de expiración

`JwtUtils` lee el payload del JWT (segundo segmento, base64url) y su claim `exp`:

- No verifica la firma: solo sirve para decidir si conviene restaurar una sesión.
- Se aplica un criterio **fail-closed**: token nulo, vacío, sin tres segmentos, con
  base64 inválido, payload que no es JSON, `exp` ausente o no numérico ⇒ **expirado**.
- La comparación es inclusiva: en el instante exacto de `exp` el token ya no es válido.
- La autoridad final sigue siendo el backend: un token manipulado que pase la
  comprobación local será rechazado con `401` y la sesión se cerrará.

El backend firma con HS256 y una expiración de 24 horas (`jwt.expiration: 86400000` ms).

### 3.4 Cierre de sesión

- El catálogo muestra un icono de salida en el `AppBar` (tooltip **Cerrar sesión**).
- Se pide confirmación con el diálogo **“¿Quieres cerrar la sesión actual?”**.
- Al confirmar, `SessionController.signOut()` borra el token del almacén seguro y pasa a
  `unauthenticated`; `SessionGate` recrea el login con los campos vacíos y la animación en
  reposo.
- El logout es **local**: el JWT es sin estado y el backend no expone revocación, por lo
  que el token seguiría siendo aceptado en el servidor hasta su `exp`.

### 3.5 Invalidación por `401`

- `ProductService` lanza `UnauthorizedException` cuando `GET /api/platillos` responde
  `401`.
- `ProductsScreen._fetchProducts()` es el **único punto** que traduce ese error en cierre
  de sesión: llama a `SessionController.expireSession()`, que borra el token, deja el
  aviso y devuelve al login.
- Sirve tanto para la carga inicial como para **Reintentar** y para deslizar hacia abajo
  (`RefreshIndicator`).
- Un `401` del **login** es distinto: sigue siendo un error de credenciales bajo la
  contraseña y no afecta a ninguna sesión existente.

### 3.6 Errores de red frente a expiración

| Situación | ¿Cierra la sesión? | Qué ve el usuario |
|---|---|---|
| `401` en el catálogo | **Sí** | Login con el aviso de sesión expirada |
| Token expirado en el arranque | **Sí** (borra el token) | Login con el aviso de sesión expirada |
| Sin conexión (`SocketException`) | No | Catálogo con mensaje y **Reintentar** |
| Tiempo agotado (10 s) | No | Catálogo con mensaje y **Reintentar** |
| `5xx` o `4xx` distintos de `401` | No | Catálogo con mensaje y **Reintentar** |
| Respuesta no interpretable | No | Catálogo con mensaje y **Reintentar** |

La sesión solo se invalida por un `401` del servidor o por expiración local del token.

---

## 4. Componentes

| Componente | Archivo | Responsabilidad |
|---|---|---|
| `SessionController` | `lib/services/session_controller.dart` | Única fuente de verdad de la sesión. Estados `restoring`, `authenticated`, `unauthenticated`; expone `restore()`, `startSession()`, `signOut()`, `expireSession()` y `consumeMessage()`. Es un `ChangeNotifier` y no depende de widgets. |
| `TokenStorage` | `lib/services/token_storage.dart` | Interfaz `read()` / `write()` / `clear()` que permite usar un doble en pruebas. |
| `SecureTokenStorage` | `lib/services/token_storage.dart` | Implementación con `flutter_secure_storage` bajo la clave `auth_token`; trata un valor vacío como ausente. |
| `JwtUtils` | `lib/utils/jwt_utils.dart` | Lectura del payload, obtención de `exp` y decisión fail-closed de expiración. No verifica la firma. |
| `SessionGate` | `lib/screens/session_gate.dart` | Escucha al controlador y decide la pantalla: indicador de restauración, `LoginScreen` o `ProductsScreen`. Sustituye a la navegación imperativa. |
| `UnauthorizedException` | `lib/services/api_exceptions.dart` | Error tipado para el `401` de un recurso protegido; es distinto de `AuthException`. |
| `AuthService` | `lib/services/auth_service.dart` | `POST /auth/login`, devuelve `AuthResponse` con el token o lanza `AuthException`. |
| `ProductService` | `lib/services/product_service.dart` | `GET /api/platillos` con `Authorization: Bearer`; devuelve `List<Platillo>` o lanza errores tipados (`UnauthorizedException`, `FormatException`, `HttpException`, `SocketException`, `TimeoutException`). |

El controlador de sesión se crea una sola vez en `main.dart` y se pasa a `SessionGate`,
`LoginScreen` y `ProductsScreen`; no se usan gestores de estado externos.

---

## 5. Estructura del proyecto

```
lib/
├── main.dart                      # Arranque: Firebase residual + SessionController + SessionGate
├── firebase_options.dart          # Configuración residual de FlutterFire (no usada en el login actual)
├── config/
│   └── api_config.dart            # API_BASE_URL y URIs de login y catálogo
├── models/
│   ├── auth_models.dart           # LoginRequest y AuthResponse
│   └── platillo.dart              # Platillo (fromJson / toJson)
├── screens/
│   ├── session_gate.dart          # Decide login, restauración o catálogo según la sesión
│   ├── login_screen.dart          # Login + animación Rive + guardado del token
│   └── products_screen.dart       # Catálogo, reintento y cierre de sesión
├── services/
│   ├── api_exceptions.dart        # UnauthorizedException
│   ├── auth_service.dart          # POST /auth/login y AuthException
│   ├── product_service.dart       # GET /api/platillos con Bearer
│   ├── session_controller.dart    # SessionController y SessionStatus
│   └── token_storage.dart         # TokenStorage y SecureTokenStorage
└── utils/
    └── jwt_utils.dart             # Lectura de exp y validación fail-closed

assets/
└── login-bear-animation.riv       # Animación Rive del oso

test/
├── config/api_config_test.dart
├── models/auth_models_test.dart
├── models/platillo_test.dart
├── services/auth_service_test.dart
├── services/product_service_test.dart
├── services/session_controller_test.dart
└── utils/jwt_utils_test.dart

evidencias/                        # Capturas y registros de ejecución real
android/ ios/ web/ ...             # Plataformas generadas por Flutter
```

---

## 6. Requisitos previos

- **Flutter 3.47.6** con Dart 3.13.5.
- **Android Studio / Android SDK** con un emulador o dispositivo Android.
- **JDK 21** para ejecutar el backend.
- **PostgreSQL** en ejecución con la base de datos `restaurant_db`.
- **Repositorio del backend** clonado en local:
  `Dave2826/restaurant-api-springboot`.

---

## 7. Backend Spring Boot

El backend es un proyecto **independiente**; este repositorio solo lo consume.

### 7.1 Endpoints utilizados

| Método | Ruta | Autenticación | Respuesta |
|---|---|---|---|
| `POST` | `/auth/login` | Pública | `200` con `{"token": "<JWT>"}` o `401` si las credenciales son inválidas |
| `GET` | `/api/platillos` | `Authorization: Bearer <token>` | `200` con la lista de platillos o `401` sin token válido |

`POST /auth/login` recibe:

```json
{ "username": "USUARIO", "password": "CONTRASENA" }
```

`GET /api/platillos` devuelve, por cada platillo:

```json
{
  "id": 1,
  "nombre": "Hamburguesa Clásica",
  "descripcion": "Carne de res con queso, lechuga y tomate.",
  "precio": 180.00,
  "categoria": "Hamburguesas",
  "disponible": true
}
```

### 7.2 Seguridad y JWT

- Spring Security con sesiones sin estado (`STATELESS`).
- `/auth/**`, `/swagger-ui/**`, `/v3/api-docs/**` y `/swagger-ui.html` son públicos.
- Todo `/api/**` requiere autenticación mediante el filtro JWT.
- El token se firma con **HS256** y expira a las **24 horas**
  (`jwt.expiration: 86400000` ms).
- El secreto (`jwt.secret`) y las credenciales de PostgreSQL se configuran en el
  backend (`src/main/resources/application.yml`); **no se documentan aquí**.
- CORS permite cualquier origen, método `GET/POST/PUT/DELETE/OPTIONS` y las cabeceras
  `Authorization` y `Content-Type`.

### 7.3 Base de datos

- Base de datos: `restaurant_db` en `localhost:5432`.
- Hibernate con `ddl-auto: update`: crea o actualiza las tablas automáticamente.
- `DataInitializer` siembra datos de ejemplo al arrancar (platillos, mesas, pedidos y
  un usuario administrador de prueba). El usuario y la contraseña sembrados se
  consultan en ese archivo del repositorio del backend; no se reproducen aquí.

### 7.4 Arranque

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

### 7.5 Verificación

```powershell
# Sin token debe responder 401
curl.exe -s -i http://localhost:8080/api/platillos
```

```powershell
# Login: obtiene el token (sustituye USUARIO y CONTRASENA)
$r = Invoke-RestMethod -Method Post -Uri http://localhost:8080/auth/login `
  -ContentType 'application/json' `
  -Body '{"username":"USUARIO","password":"CONTRASENA"}'
$r.token
```

```powershell
# Catálogo con el token
curl.exe -s -H "Authorization: Bearer <TOKEN>" http://localhost:8080/api/platillos
```

La documentación interactiva de la API (springdoc) queda en
`http://localhost:8080/swagger-ui/index.html`.

---

## 8. Configuración de `API_BASE_URL`

La URL del backend se define en tiempo de compilación en `lib/config/api_config.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
```

- **Valor por defecto:** `http://10.0.2.2:8080`, la dirección con la que el emulador
  Android alcanza el equipo anfitrión.
- **Sobrescritura sin tocar el código:**

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Las URIs se derivan de esa base:

| Constante | Valor |
|---|---|
| `ApiConfig.loginUri` | `{API_BASE_URL}/auth/login` |
| `ApiConfig.platillosUri` | `{API_BASE_URL}/api/platillos` |

---

## 9. Ejecución en emulador Android

1. Arranca PostgreSQL y el backend (sección 7) y confirma que responde en
   `http://localhost:8080`.
2. Inicia el emulador, por ejemplo:

   ```bash
   flutter emulators --launch Pixel_7
   ```

3. Comprueba que Flutter lo detecta:

   ```bash
   flutter devices
   ```

4. Instala dependencias y ejecuta la app:

   ```bash
   flutter pub get
   flutter run
   ```

5. En la primera ejecución, escribe el usuario y la contraseña sembrados por el backend
   y pulsa **Login**. Tras la animación de éxito se abre el catálogo.

Compilación de un APK de depuración (opcional):

```bash
flutter build apk --debug
```

El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

### 9.1 Comprobación manual de la sesión

Con el backend en marcha y el emulador conectado:

| Escenario | Acción | Resultado esperado |
|---|---|---|
| Restauración | Login correcto, cerrar la app y volver a abrirla | Se abre el catálogo sin pedir credenciales |
| Sesión cerrada | Pulsar **Cerrar sesión** en el `AppBar` y confirmar | Vuelve al login; al reabrir la app sigue en login |
| Token expirado | Usar un token caducado (por ejemplo, arrancar el backend con `--jwt.expiration=60000` y esperar) y recargar el catálogo | Redirección al login con `Tu sesión expiró o ya no es válida. Inicia sesión de nuevo.` |
| `401` del servidor | Reiniciar el backend con otro `jwt.secret` y recargar | El catálogo responde `401` y la app vuelve al login con el aviso |
| Sin red | Detener el backend y recargar el catálogo | Mensaje de conexión con **Reintentar**; la sesión **no** se cierra |

Para forzar un arranque en frío desde la terminal:

```bash
adb shell am force-stop com.example.login_drive_animation
```

---

## 10. Manejo de errores

### 10.1 Login (`AuthService`)

| Situación | Resultado | Dónde se muestra |
|---|---|---|
| `401` | `Credenciales de acceso inválidas.` | Bajo el campo de contraseña |
| `200` sin `token` | `Respuesta del servidor sin token de autenticación.` | Banner general |
| Otro código HTTP | `Error del servidor al iniciar sesión (<código>).` | Banner general |
| Sin conexión (`SocketException`) | `No se pudo conectar con el servidor. Revisa tu conexión.` | Banner general |
| Tiempo agotado (10 s) | `El servidor tardó demasiado en responder. Inténtalo más tarde.` | Banner general |
| Falla de transporte (`ClientException`) | `Error de comunicación de red al conectar con el servidor.` | Banner general |
| Respuesta no interpretable | `Formato de respuesta del servidor no reconocido.` | Banner general |

El banner general aparece encima del botón **Login** y se limpia al editar cualquier
campo o al reintentar. En todos los casos fallidos el oso reproduce la animación de
fallo. El mismo banner muestra el aviso de sesión expirada o invalidada cuando la app
regresa al login.

### 10.2 Catálogo y sesión (`ProductService`, `ProductsScreen`)

| Situación | Resultado | ¿Cierra la sesión? |
|---|---|---|
| `200` con lista válida | Lista de `Platillo` | No |
| `200` con JSON que no es lista, o con un elemento que no es objeto | `FormatException` → `No se pudo interpretar la respuesta del catálogo.` | No |
| `401` | `UnauthorizedException` → aviso en el login | **Sí** |
| `>= 500` | `Error interno en el servidor al cargar los platillos.` | No |
| Otro código | `Error del servidor al obtener platillos (<código>).` | No |
| Sin conexión | `No fue posible conectar con el servidor.` | No |
| Tiempo agotado (10 s) | `Tiempo de espera agotado al conectar con el servidor.` | No |

`ProductsScreen` traduce los errores no relacionados con la sesión a mensajes de
pantalla e invita a reintentar; el `401` se resuelve cerrando la sesión.

---

## 11. Pruebas automatizadas

La suite usa `flutter_test`, `MockClient` de `package:http/testing.dart` y un
almacenamiento de tokens falso en memoria; no requiere backend, emulador ni canales
nativos.

| Archivo | Pruebas | Cobertura |
|---|---:|---|
| `test/config/api_config_test.dart` | 5 | URL por defecto y override, URIs de login y catálogo, host y puerto |
| `test/models/auth_models_test.dart` | 5 | `LoginRequest.toJson`, `AuthResponse.fromJson` (token, ausente, nulo) y `toJson` |
| `test/models/platillo_test.dart` | 8 | JSON completo, campos nulos, precio entero y decimal, `disponible`, `toJson` |
| `test/services/auth_service_test.dart` | 10 | Solicitud, token, `401`, `500`, `200` sin token, JSON inválido, timeout, conexión, transporte y error inesperado |
| `test/services/product_service_test.dart` | 12 | Solicitud, Bearer, lista válida, lista vacía, acentos UTF-8, no-lista, elemento no-objeto, JSON inválido, `401` tipado, `500`, `400`, timeout y conexión |
| `test/services/session_controller_test.dart` | 16 | Estado inicial, restauración (sin token, vigente, expirado, malformado, sin `exp`, fallo de lectura, idempotencia), `startSession`, `signOut`, `expireSession`, avisos y notificaciones |
| `test/utils/jwt_utils_test.dart` | 15 | Payload válido, token nulo/vacío, segmentos insuficientes, base64 inválido, payload no JSON, `exp` UTC, futuro, pasado, instante exacto y fail-closed |
| **Total** | **71** | |

Ejecución:

```bash
flutter test
```

Resultado verificado: `All tests passed!` con 71 pruebas.

Análisis estático:

```bash
flutter analyze
```

Resultado verificado: `No issues found!`.

### Comprobación del override de `API_BASE_URL`

El test de configuración compara `ApiConfig.baseUrl` con el valor compilado en
`EXPECTED_API_BASE_URL`. Sin defines verifica el valor por defecto; con defines verifica
la sobrescritura:

```bash
flutter test test/config/api_config_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:9999 --dart-define=EXPECTED_API_BASE_URL=http://127.0.0.1:9999
```

---

## 12. Evidencias

Carpeta `evidencias/`. Capturas y registros de ejecuciones reales del flujo actual
contra el backend Spring Boot.

| Archivo | Tipo | Qué muestra |
|---|---|---|
| `01-login-screen.png` | Imagen | Pantalla de login con el oso Rive y los campos **Usuario** / **Password** |
| `02-login-error-credenciales.png` | Imagen | Respuesta `401` del login: `Credenciales de acceso inválidas.` bajo la contraseña |
| `03-login-exitoso.png` | Imagen | Animación de éxito del oso antes de pasar al catálogo |
| `04-catalogo-platillos.png` | Imagen | Catálogo cargado desde `GET /api/platillos` |
| `05-backend-http.txt` | Registro | Comprobaciones HTTP reales: `401` sin token, `200` en login y `200` en el catálogo; token redactado |
| `06-flutter-test.txt` | Registro | Salida completa de `flutter test` (71 pruebas) |
| `07-flutter-analyze.txt` | Registro | Salida de `flutter analyze` (`No issues found!`) |

Los archivos `.txt` contienen la salida de consola de las ejecuciones correspondientes.
En `05-backend-http.txt` el token JWT aparece redactado y la contraseña no se registra;
en `06-flutter-test.txt` y `07-flutter-analyze.txt` no se imprime ningún token.

Las capturas anteriores a la gestión de sesión (`01`–`04`) siguen siendo válidas: el
login, sus mensajes y el catálogo no cambiaron. `05-backend-http.txt` también sigue
vigente porque los endpoints y sus respuestas no se modificaron.

### Evidencias pendientes

Faltan capturas reales de las funcionalidades de sesión implementadas. No se han
generado imágenes simuladas:

| Evidencia sugerida | Qué debería mostrar |
|---|---|
| `08-sesion-restaurada.png` | Catálogo abierto al reabrir la app con un token guardado, sin pasar por el login |
| `09-cerrar-sesion.png` | Diálogo de confirmación de cierre de sesión y regreso al login |
| `10-sesion-expirada.png` | Login con el aviso `Tu sesión expiró o ya no es válida. Inicia sesión de nuevo.` |

Para generarlas se necesita el backend en marcha y el emulador con la app instalada
(pasos de la sección 9.1).

---

## 13. Estado residual de Firebase

Firebase **sigue presente** en el proyecto, pero **ya no participa en el login**.

- `pubspec.yaml` mantiene `firebase_core` 5.2.0 y `firebase_auth` 7.1.0.
- `lib/main.dart` sigue llamando a `Firebase.initializeApp(...)` antes de montar la app.
- Permanecen `lib/firebase_options.dart`, `firebase.json` y
  `android/app/google-services.json`.
- Ninguna pantalla ni servicio usa `firebase_auth`: la autenticación actual es
  usuario/contraseña contra Spring Boot con JWT.

Estos elementos se conservan mientras no se autorice su retirada; no afectan al flujo
descrito en este documento.

---

## 14. Limitaciones y consideraciones

1. **Sin renovación de token:** no hay refresh token. Cuando el JWT expira (24 h) o el
   servidor lo rechaza, la sesión se cierra y hay que iniciar sesión de nuevo.
2. **Logout local:** el cierre de sesión borra el token del dispositivo, pero no lo
   revoca en el backend (JWT sin estado y sin endpoint de revocación).
3. **Validación local sin firma:** `JwtUtils` solo lee `exp`; no verifica la firma ni el
   emisor. La comprobación definitiva la hace el servidor con el `401`.
4. **Elementos sin funcionalidad:** `Forgot password?` y `Register` son elementos
   visuales sin acción asociada.
5. **Validación estricta de tipos incompleta:** el servicio valida que la respuesta sea
   una lista de objetos, pero `Platillo.fromJson` asigna los campos con `as`; un valor
   con tipo incorrecto (por ejemplo `"id": "1"`) produciría un `TypeError` no
   controlado. Con los datos actuales del backend (`id` entero, `precio` numérico,
   `disponible` booleano) no ocurre. Algo similar puede pasar si la respuesta `200` del
   login no es un objeto JSON.
6. **Valores por defecto silenciosos:** si faltan campos obligatorios en un platillo,
   el modelo usa `id: 0`, `nombre: ''`, `precio: 0.0` y `disponible: false`.
7. **Timeout cubierto de forma simulada:** las pruebas inyectan `TimeoutException`; no
   esperan los 10 segundos reales.
8. **Sin cobertura de widget:** no hay pruebas de widget para `SessionGate`,
   `LoginScreen` ni `ProductsScreen`; su validación es manual en el emulador.
9. **Backup de Android:** la app no desactiva `android:allowBackup`, por lo que restaurar
   una copia de seguridad en otro dispositivo puede invalidar la clave del almacén. El
   error se captura y la sesión se cierra sin bloqueos.
10. **Sin integración continua:** las pruebas no se ejecutan automáticamente en un
    pipeline.
11. **HTTP sin TLS:** la app declara `android:usesCleartextTraffic="true"` y el permiso
    `INTERNET` para consumir el backend local por HTTP. En producción debe usarse HTTPS
    y retirar esa bandera.
12. **CORS abierto en el backend:** útil para desarrollo, no apto para producción.
13. **Retraso fijo de animación:** el login espera 700 ms antes de disparar el trigger de
    éxito y 2 s adicionales antes de guardar el token y mostrar el catálogo.

---

## 15. Nota sobre `10.0.2.2`

El emulador Android se ejecuta en una red virtual: dentro del emulador, `localhost` es
el propio emulador, no el equipo anfitrión. Por eso la app usa `10.0.2.2`.

- **Emulador + backend en la misma máquina:** `http://10.0.2.2:8080` (valor por defecto).
- **Dispositivo físico:** usa la IP del equipo en la red local, por ejemplo
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`.

---

## Notas finales

- Proyecto desarrollado como actividad académica.
- El backend y PostgreSQL viven en un repositorio y una base de datos independientes de
  esta aplicación.
- Este documento no incluye contraseñas, secretos JWT, tokens reales ni rutas locales
  personales.
