# Login animado con Rive, autenticación JWT y catálogo de platillos

Aplicación Flutter con un login animado creado en Rive que se autentica contra un
backend Spring Boot propio mediante JWT y, tras el acceso, consulta el catálogo de
platillos en PostgreSQL y lo muestra en pantalla.

Repositorio de la aplicación: <https://github.com/Dave2826/rive-login-experience>

Backend (repositorio independiente): <https://github.com/Dave2826/restaurant-api-springboot>

---

## 1. Objetivo

Integrar en una sola aplicación Flutter:

- Una pantalla de login con una animación interactiva creada en Rive.
- Autenticación real contra un backend Spring Boot que valida usuario y contraseña y
  emite un token JWT.
- Uso del token JWT como credencial `Bearer` para consumir el catálogo protegido.
- Una pantalla que lista los platillos obtenidos de PostgreSQL, con estados de carga,
  error con reintento, lista vacía y lista con datos.

Flujo resultante: **login animado → `POST /auth/login` → JWT → `GET /api/platillos` → catálogo**.

---

## 2. Tecnologías

### Aplicación Flutter

| Tecnología | Versión (verificada con `pubspec.lock` / `flutter --version`) |
|---|---|
| Flutter (stable) | 3.47.6 |
| Dart | 3.13.5 (`sdk: ^3.13.5`) |
| `http` | 1.6.0 |
| `rive` | 0.13.20 |
| `flutter_lints` | 6.0.0 |
| `flutter_test` (dev) | SDK de Flutter |
| Paquete | `login_drive_animation` |

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

## 3. Arquitectura y flujo

```
┌────────────────────────────────┐
│ Flutter (Android)              │
│ Login animado con Rive         │
└───────────────┬────────────────┘
                │ 1. POST /auth/login  {"username","password"}
                ▼
┌────────────────────────────────┐
│ Spring Boot :8080              │
│ Spring Security + JWT (HS256)  │
│ 2. Valida credenciales contra  │
│    la tabla de usuarios        │
│ 3. Devuelve {"token":"..."}    │
└───────────────┬────────────────┘
                │ 4. GET /api/platillos
                │    Authorization: Bearer <token>
                ▼
┌────────────────────────────────┐
│ Spring Boot                    │
│ 5. Valida el token y consulta  │
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│ PostgreSQL (restaurant_db)     │
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│ 6. Lista de platillos en       │
│    pantalla                    │
└────────────────────────────────┘
```

### Comportamiento del login

1. El oso de Rive sigue la escritura del usuario, se tapa los ojos mientras se escribe
   la contraseña y reacciona al pulsar **Login**.
2. Validación local antes de llamar al backend: si el usuario o la contraseña están
   vacíos se muestra `Ingresa tu usuario` / `Ingresa tu contraseña` bajo el campo
   correspondiente y el oso reproduce la animación de fallo. No se envía ninguna
   petición.
3. Si ambos campos tienen contenido, se ejecuta `POST /auth/login`.
4. Con credenciales correctas se apaga el indicador de carga, el oso celebra y, tras
   unos 2 segundos, la app navega a la pantalla del catálogo pasando el token.
5. Mientras se procesa el intento, el botón muestra un indicador circular y se
   bloquean los envíos duplicados.

### Comportamiento del catálogo

`ProductsScreen` consulta `GET /api/platillos` al abrirse y muestra:

- **Carga:** indicador circular centrado.
- **Error:** icono, mensaje descriptivo y botón **Reintentar**.
- **Lista vacía:** `No hay platillos disponibles`.
- **Datos:** una tarjeta por platillo con nombre, descripción (máximo 2 líneas),
  categoría, estado `Disponible` / `Agotado` y precio con dos decimales.
- **Actualización:** deslizar hacia abajo (`RefreshIndicator`) vuelve a consultar el
  catálogo.

---

## 4. Estructura del proyecto

```
lib/
├── main.dart                     # Arranque de la app (incluye la inicialización residual de Firebase)
├── firebase_options.dart         # Configuración residual de FlutterFire (no usada en el login actual)
├── config/
│   └── api_config.dart           # API_BASE_URL y URIs de login y catálogo
├── models/
│   ├── auth_models.dart          # LoginRequest y AuthResponse
│   └── platillo.dart             # Platillo (fromJson / toJson)
├── screens/
│   ├── login_screen.dart         # Login + animación Rive + llamada al backend
│   └── products_screen.dart      # Catálogo, estados y reintento
└── services/
    ├── auth_service.dart         # POST /auth/login y AuthException
    └── product_service.dart      # GET /api/platillos con Bearer

assets/
└── login-bear-animation.riv      # Animación Rive del oso

test/
├── config/api_config_test.dart
├── models/auth_models_test.dart
├── models/platillo_test.dart
├── services/auth_service_test.dart
└── services/product_service_test.dart

evidencias/                       # Capturas y registros de ejecución real
android/ ios/ web/ ...            # Plataformas generadas por Flutter
```

---

## 5. Requisitos previos

- **Flutter 3.47.6** con Dart 3.13.5.
- **Android Studio / Android SDK** con un emulador o dispositivo Android.
- **JDK 21** para ejecutar el backend.
- **PostgreSQL** en ejecución con la base de datos `restaurant_db`.
- **Repositorio del backend** clonado en local:
  `Dave2826/restaurant-api-springboot`.

---

## 6. Backend Spring Boot

El backend es un proyecto **independiente**; este repositorio solo lo consume.

### 6.1 Endpoints utilizados

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

### 6.2 Seguridad y JWT

- Spring Security con sesiones sin estado (`STATELESS`).
- `/auth/**`, `/swagger-ui/**`, `/v3/api-docs/**` y `/swagger-ui.html` son públicos.
- Todo `/api/**` requiere autenticación mediante el filtro JWT.
- El token se firma con **HS256** y expira a las **24 horas**
  (`jwt.expiration: 86400000` ms).
- El secreto (`jwt.secret`) y las credenciales de PostgreSQL se configuran en el
  backend (`src/main/resources/application.yml`); **no se documentan aquí**.
- CORS permite cualquier origen, método `GET/POST/PUT/DELETE/OPTIONS` y las cabeceras
  `Authorization` y `Content-Type`.

### 6.3 Base de datos

- Base de datos: `restaurant_db` en `localhost:5432`.
- Hibernate con `ddl-auto: update`: crea o actualiza las tablas automáticamente.
- `DataInitializer` siembra datos de ejemplo al arrancar (platillos, mesas, pedidos y
  un usuario administrador de prueba). El usuario y la contraseña sembrados se
  consultan en ese archivo del repositorio del backend; no se reproducen aquí.

### 6.4 Arranque

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

### 6.5 Verificación

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

## 7. Configuración de `API_BASE_URL`

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

## 8. Ejecución en emulador Android

1. Arranca PostgreSQL y el backend (sección 6) y confirma que responde en
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

5. En la app, escribe el usuario y la contraseña sembrados por el backend y pulsa
   **Login**. Tras la animación de éxito se abre el catálogo.

Compilación de un APK de depuración (opcional):

```bash
flutter build apk --debug
```

El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 9. Manejo de errores

### 9.1 Login (`AuthService`)

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
fallo.

### 9.2 Catálogo (`ProductService` y `ProductsScreen`)

| Situación | Resultado |
|---|---|
| `200` con lista válida | Lista de `Platillo` |
| `200` con JSON que no es lista, o con un elemento que no es objeto | `FormatException` → `No se pudo interpretar la respuesta del catálogo.` |
| `401` | `Sesión no autorizada o token inválido.` |
| `>= 500` | `Error interno en el servidor al cargar los platillos.` |
| Otro código | `Error del servidor al obtener platillos (<código>).` |
| Sin conexión | `No fue posible conectar con el servidor.` |
| Tiempo agotado (10 s) | `Tiempo de espera agotado al conectar con el servidor.` |

`ProductsScreen` traduce estos errores a mensajes de pantalla e invita a reintentar.

---

## 10. Pruebas automatizadas

La suite usa `flutter_test` y `MockClient` de `package:http/testing.dart`; no requiere
backend ni emulador en ejecución.

| Archivo | Pruebas | Cobertura |
|---|---:|---|
| `test/config/api_config_test.dart` | 5 | URL por defecto y override, URIs de login y catálogo, host y puerto |
| `test/models/auth_models_test.dart` | 5 | `LoginRequest.toJson`, `AuthResponse.fromJson` (token, ausente, nulo) y `toJson` |
| `test/models/platillo_test.dart` | 8 | JSON completo, campos nulos, precio entero y decimal, `disponible`, `toJson` |
| `test/services/auth_service_test.dart` | 10 | Solicitud, token, `401`, `500`, `200` sin token, JSON inválido, timeout, conexión, transporte y error inesperado |
| `test/services/product_service_test.dart` | 12 | Solicitud, Bearer, lista válida, lista vacía, acentos UTF-8, no-lista, elemento no-objeto, JSON inválido, `401`, `500`, `400`, timeout y conexión |
| **Total** | **40** | |

Ejecución:

```bash
flutter test
```

Resultado verificado: `All tests passed!` con 40 pruebas.

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

## 11. Evidencias

Carpeta `evidencias/`. Todas las capturas corresponden a ejecuciones reales del flujo
actual contra el backend Spring Boot.

| Archivo | Tipo | Qué muestra |
|---|---|---|
| `01-login-screen.png` | Imagen | Pantalla de login con el oso Rive y los campos **Usuario** / **Password** |
| `02-login-error-credenciales.png` | Imagen | Respuesta `401`: mensaje `Credenciales de acceso inválidas.` bajo la contraseña |
| `03-login-exitoso.png` | Imagen | Animación de éxito del oso tras autenticarse, antes de navegar |
| `04-catalogo-platillos.png` | Imagen | Catálogo cargado desde `GET /api/platillos` |
| `05-backend-http.txt` | Registro | Comprobaciones HTTP reales: `401` sin token, `200` en login y `200` en el catálogo; token redactado |
| `06-flutter-test.txt` | Registro | Salida completa de `flutter test` (40 pruebas) |
| `07-flutter-analyze.txt` | Registro | Salida de `flutter analyze` (`No issues found!`) |

Los archivos `.txt` son la salida de consola de las ejecuciones correspondientes. En
`05-backend-http.txt` el token JWT aparece redactado y la contraseña no se registra.

---

## 12. Estado residual de Firebase

Firebase **sigue presente** en el proyecto, pero **ya no participa en el login**.

- `pubspec.yaml` mantiene `firebase_core` 5.2.0 y `firebase_auth` 7.1.0.
- `lib/main.dart` sigue llamando a `Firebase.initializeApp(...)`.
- Permanecen `lib/firebase_options.dart`, `firebase.json` y
  `android/app/google-services.json`.
- Ninguna pantalla ni servicio usa `firebase_auth`: la autenticación actual es
  usuario/contraseña contra Spring Boot con JWT.

Estos elementos se conservan mientras no se autorice su retirada; no afectan al flujo
descrito en este documento.

---

## 13. Limitaciones y consideraciones

1. **Token solo en memoria:** el JWT se pasa a `ProductsScreen` y no se persiste. Al
   reiniciar la app hay que volver a iniciar sesión y no existe renovación automática;
   cuando el token expira (24 h), el catálogo responde `401`.
2. **Elementos sin funcionalidad:** `Forgot password?` y `Register` son elementos
   visuales sin acción asociada.
3. **Validación estricta de tipos incompleta:** el servicio valida que la respuesta sea
   una lista de objetos, pero `Platillo.fromJson` asigna los campos con `as`; un valor
   con tipo incorrecto (por ejemplo `"id": "1"`) produciría un `TypeError` no
   controlado. Con los datos actuales del backend (`id` entero, `precio` numérico,
   `disponible` booleano) no ocurre.
4. **Valores por defecto silenciosos:** si faltan campos obligatorios en un platillo,
   el modelo usa `id: 0`, `nombre: ''`, `precio: 0.0` y `disponible: false`.
5. **Timeout cubierto de forma simulada:** las pruebas inyectan `TimeoutException`; no
   esperan los 10 segundos reales.
6. **Sin cobertura de pantallas:** no hay pruebas de widget para `LoginScreen` ni
   `ProductsScreen`; su validación es manual en el emulador.
7. **Sin integración continua:** las pruebas no se ejecutan automáticamente en un
   pipeline.
8. **HTTP sin TLS:** la app declara `android:usesCleartextTraffic="true"` y el permiso
   `INTERNET` para consumir el backend local por HTTP. En producción debe usarse HTTPS
   y retirar esa bandera.
9. **CORS abierto en el backend:** útil para desarrollo, no apto para producción.
10. **Retraso fijo de animación:** el login espera 700 ms antes de disparar el trigger de
    éxito y 2 s adicionales antes de navegar.

---

## 14. Nota sobre `10.0.2.2`

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
