# flutter_clean_arch CLI

[![CI](https://github.com/andresbra23123/flutter_clean_arch_cli/actions/workflows/ci.yml/badge.svg)](https://github.com/andresbra23123/flutter_clean_arch_cli/actions/workflows/ci.yml) [![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-blue.svg)](LICENSE)

Repositorio: [andresbra23123/flutter_clean_arch_cli](https://github.com/andresbra23123/flutter_clean_arch_cli) · Comando: `flutter_clean_arch` · [Cambios por versión](CHANGELOG.md)

CLI que genera y hace crecer proyectos Flutter con Clean Architecture. Con `init` crea la base del proyecto: `core`, app, flavors, l10n y DI, y opcionalmente autenticación con Firebase. Después agrega features completas, páginas, BLoCs, casos de uso, componentes, widgets, modelos desde JSON y tests, y los registra en el DI y en el router. También puede renombrar o eliminar lo que generó, y `doctor` revisa que el proyecto siga las convenciones.

## Contenido

- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Ayuda](#ayuda)
- [Inicio rápido](#inicio-rápido)
- [Estructura generada](#estructura-generada)
- [Convenciones](#convenciones)
- [Comandos](#comandos)
  - Crear: [init](#flutter_clean_arch-init), [auth](#flutter_clean_arch-auth), [feature](#flutter_clean_arch-feature-nombre), [page](#flutter_clean_arch-page-feature-nombre), [bloc](#flutter_clean_arch-bloc-feature-nombre), [usecase](#flutter_clean_arch-usecase-feature-nombre), [component](#flutter_clean_arch-component-feature-página-nombre), [widget](#flutter_clean_arch-widget-feature-nombre), [model](#flutter_clean_arch-model-feature-nombre---from-json-archivo), [test](#flutter_clean_arch-test-feature)
  - Modificar: [rename](#flutter_clean_arch-rename), [remove](#flutter_clean_arch-remove)
  - Revisar: [doctor](#flutter_clean_arch-doctor)
  - [Protecciones](#protecciones) y [códigos de salida](#códigos-de-salida)
- [Nombres válidos](#nombres-válidos)
- [Marcadores](#marcadores)
- [Solución de problemas](#solución-de-problemas)
- [Modificar la CLI](#modificar-la-cli)
- [Licencia](#licencia)

## Requisitos

- Dart SDK `^3.12.0` y Flutter.
- En Windows, el **Modo de desarrollador** activado para compilar proyectos con plugins (`start ms-settings:developers`).
- Para `auth`: una cuenta de Firebase y la [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) (`dart pub global activate flutterfire_cli`).
- Recomendado: el proyecto en un repositorio git. La CLI lo usa para protegerte de perder cambios (ver [Protecciones](#protecciones)).

## Instalación

Desde GitHub (recomendado):

```bash
dart pub global activate --source git https://github.com/andresbra23123/flutter_clean_arch_cli
```

| Para… | Comando |
|---|---|
| Actualizar a la última versión de `main` | El mismo comando de instalación |
| Instalar una versión fija | `dart pub global activate --source git https://github.com/andresbra23123/flutter_clean_arch_cli --git-ref v0.2.0` |
| Ver la versión instalada | `flutter_clean_arch --version` (o `dart pub global list`, que además dice desde dónde está instalada) |
| Desinstalar | `dart pub global deactivate flutter_clean_arch` |

- El ejecutable queda en la carpeta `bin` del pub cache, que debe estar en el `PATH`: `%LOCALAPPDATA%\Pub\Cache\bin` en Windows y `~/.pub-cache/bin` en macOS y Linux.
- En Git Bash se llama como `flutter_clean_arch.bat`.
- La primera ejecución después de instalar o actualizar muestra «Building package executable…» mientras se compila.

Para instalarla desde una copia local (por ejemplo, para modificar las plantillas), mira [Modificar la CLI](#modificar-la-cli).

## Ayuda

La CLI trae ayuda integrada:

| Comando | Muestra |
|---|---|
| `flutter_clean_arch --help` (o `-h`, o `help`) | La lista de comandos con su descripción. |
| `flutter_clean_arch help <comando>` | El uso y las opciones de un comando, con sus valores por defecto. |
| `flutter_clean_arch <comando> --help` | Lo mismo que el anterior. |
| `flutter_clean_arch help remove feature` | La ayuda de un subcomando (`remove` y `rename` tienen subcomandos). |
| `flutter_clean_arch --version` (o `-v`) | La versión instalada, por ejemplo `flutter_clean_arch 0.2.0`. |

`help` solo recibe nombres de comandos: para ver qué hace `--returns`, usa `help usecase`, no `help usecase --returns`.

```text
$ flutter_clean_arch --help
Genera la estructura Clean Architecture de un proyecto Flutter.

Uso: flutter_clean_arch <comando> [argumentos]

Opciones globales:
-h, --help       Muestra esta ayuda.
-v, --version    Muestra la versión instalada.

Comandos:
  auth        Agrega autenticación con Firebase (email + Google): la feature auth, sus tests, la redirección del router y las opciones por flavor.
  bloc        Agrega un BLoC (o un Cubit con --cubit) en su propia carpeta a una feature y lo registra en el DI.
  component   Agrega un componente a la carpeta components/ de una página y lo exporta en su barril.
  doctor      Revisa que cada carpeta tenga su barril, que existan los marcadores y que cada feature esté registrada en el DI.
  feature     Crea una feature (data, domain, presentation y barriles) y la registra en el DI y el router.
  init        Crea la estructura general: core, app, bootstrap, flavors, home, página no encontrada, l10n y dependencias.
  model       Genera la entidad y el modelo (fromJson/toJson) de una feature a partir de un JSON de ejemplo, incluidos los objetos anidados.
  page        Agrega una página (con su carpeta components/) a una feature y registra su ruta.
  remove      Elimina una feature, página, BLoC o use case y deshace sus exports, registros en el DI y rutas.
  rename      Renombra una feature, página o BLoC: carpetas, archivos, clases, exports, DI y rutas.
  test        Genera los tests de una feature: use case, repositorio, BLoC y página (bloc_test y mocktail).
  usecase     Agrega un use case a una feature, su método al repositorio (Inter e Impl) y lo registra en el DI.
  widget      Agrega un widget compartido a presentation/widgets/ de una feature y lo exporta en su barril.
```

### Errores de uso

Cuando algo está mal escrito, la CLI explica qué pasó y cómo corregirlo, en español, y termina con código 64. Revisa los argumentos antes que el proyecto, así que un error de uso se ve aunque no estés en un proyecto Flutter.

| Error | Ejemplo | Respuesta |
|---|---|---|
| Opciones sin comando | `flutter_clean_arch --auth --force` | «Falta el comando: `--auth` es una opción de `init`» y la llamada corregida: `init --auth --force` |
| Opción de un subcomando | `flutter_clean_arch --yes` | Lista `remove feature`, `remove page`…, `rename feature`… |
| Comando mal escrito | `flutter_clean_arch usecas songs x` o `help usecas` | «No existe el comando `usecas`. ¿Quisiste decir `usecase`?» |
| Subcomando mal escrito | `flutter_clean_arch remove pag songs x` | «No existe el comando `pag` en `remove`. ¿Quisiste decir `page`?» |
| Falta el subcomando | `flutter_clean_arch remove --yes` | «Falta el subcomando de `remove`: `feature`, `page`, `bloc`, `usecase`» |
| Opción mal escrita | `flutter_clean_arch init --auht` | «¿Quisiste decir `--auth`?» y la ayuda de `init` |
| Opción de otro comando | `flutter_clean_arch init --tests` | «`--tests` es una opción de `feature`» |
| Faltan argumentos u opciones obligatorias | `flutter_clean_arch model songs song` | «Falta la opción obligatoria --from-json <archivo>» y la ayuda de `model` |

La ayuda que genera la librería `args` («Usage», «Print this usage information», «defaults to»…) también se muestra en español.

## Inicio rápido

```bash
flutter create --org com.example mi_app
cd mi_app

# Base del proyecto. --force porque flutter create ya trae analysis_options.yaml.
# Añade --auth para incluir login con Firebase (email + Google).
flutter_clean_arch init --force

# Recomendado: guarda el punto de partida en git. Así podrás deshacer cualquier
# comando, y remove, rename y --force te avisarán si hay cambios sin guardar.
git init && git add -A && git commit -m "init"

# Feature completa con su página, su BLoC, su ruta /songs y sus tests.
flutter_clean_arch feature songs --tests

# Entidad y modelo a partir de una respuesta real de la API.
flutter_clean_arch model songs song --from-json song.json

# Otra página dentro de la feature, con su propio BLoC y un componente.
flutter_clean_arch page songs song_detail --bloc
flutter_clean_arch component songs song_detail cover

# Un caso de uso nuevo: firma en el repositorio y registro en el DI.
flutter_clean_arch usecase songs search_songs --returns "List<SongEntity>" --params String

# Comprobar que todo sigue las convenciones.
flutter_clean_arch doctor

flutter run --flavor development -t lib/main_development.dart
flutter test
```

## Estructura generada

### Después de `init`

```text
lib/
├─ main_development.dart        Punto de entrada de cada flavor
├─ main_staging.dart
├─ main_production.dart
├─ bootstrap.dart               Inicializa el DI y arranca la app
├─ app/
│  ├─ app.dart                  Barril
│  └─ pages/
│     ├─ pages.dart
│     └─ app.dart               MaterialApp.router con tema y l10n
├─ core/
│  ├─ animations/               Transiciones de go_router (routerAnimation)
│  ├─ api/                      ApiClient (dio), interceptor, toAppException() y ApiDateFormat
│  ├─ constants/                AppConstants (baseUrl, nombre, paginación…)
│  ├─ di/                       injection_container.dart (get_it) + barril
│  ├─ errors/                   Exceptions (data) y Failures (domain)
│  ├─ l10n/                     arb/ (en, es), gen/ (generado) y extensión context.l10n
│  ├─ mixings/                  Validator: validaciones de formularios traducidas
│  ├─ network/                  NetworkInfoInter / NetworkInfoImpl
│  ├─ router/                   AppRouter, AppRoutes, NotFoundPage, GoRouterRefreshStream
│  ├─ theme/                    AppColors, AppTextStyles, AppTheme
│  ├─ type_defs/                EitherOr<T>, FutureEither<T>, StreamEither<T> y toEither()
│  ├─ usecases/                 UseCaseInter, UseCaseInterStream (streams), UseCaseInterSync y NoParams
│  ├─ utils/                    AppUtils, ClockInter (reloj) e IdGeneratorInter (uuid)
│  └─ validation/               ValidationRules: reglas puras que comparten domain y los formularios
└─ features/
   └─ home/
      ├─ home.dart
      └─ presentation/
         ├─ presentation.dart
         └─ pages/
            ├─ pages.dart
            └─ home/
               ├─ home.dart
               ├─ home_page.dart
               └─ components/
                  ├─ components.dart
                  └─ home_welcome.dart
test/core/                      Tests de type_defs, api_error, utils y validation
test/helpers/                   pumpApp y barril
.vscode/launch.json             Launch development/staging/production y depuración de tests
l10n.yaml, analysis_options.yaml
.flutter_clean_arch.yaml        Versiones de la CLI que crearon y modificaron el proyecto
```

`.flutter_clean_arch.yaml` se actualiza cada vez que un comando cambia el proyecto. Inclúyelo en git: `doctor` lo usa para avisar cuando la CLI instalada y el proyecto no coinciden.

```yaml
created_with: 0.2.0
last_modified_with: 0.2.0
auth: true
```

Cada carpeta de `core/` tiene su barril, por ejemplo `core/router/router.dart`.

### Una feature (`feature songs`)

```text
lib/features/songs/
├─ songs.dart                           Barril de la feature
├─ songs_injection.dart                 initSongsDependencies()
├─ data/
│  ├─ data.dart
│  ├─ datasources/
│  │  ├─ datasources.dart
│  │  ├─ local/   local.dart, songs_local_datasource_inter.dart, songs_local_datasource_impl.dart
│  │  └─ remote/  remote.dart, songs_endpoints.dart, songs_remote_datasource_inter.dart, songs_remote_datasource_impl.dart
│  ├─ models/        models.dart, songs_model.dart
│  └─ repositories/  repositories.dart, songs_repository_impl.dart
├─ domain/
│  ├─ domain.dart
│  ├─ entities/      entities.dart, songs_entity.dart
│  ├─ errors/        errors.dart, songs_error_codes.dart
│  ├─ repositories/  repositories.dart, songs_repository_inter.dart
│  └─ usecases/      usecases.dart, get_songs.dart
└─ presentation/
   ├─ presentation.dart
   ├─ bloc/
   │  ├─ bloc.dart
   │  └─ songs/      songs.dart, songs_bloc.dart, songs_event.dart, songs_state.dart
   ├─ pages/
   │  ├─ pages.dart
   │  └─ songs/
   │     ├─ songs.dart
   │     ├─ songs_page.dart
   │     └─ components/  components.dart, songs_error_view.dart
   └─ widgets/       widgets.dart, songs_widget.dart
```

## Convenciones

- **Un barril por carpeta.** Cada carpeta con archivos Dart tiene `<carpeta>/<carpeta>.dart`, con un comentario `///`, `library;` y sus `export` ordenados. El barril de una carpeta exporta los barriles de sus subcarpetas, no sus archivos sueltos. Desde fuera de una capa se importa su barril, por ejemplo `features/songs/domain/domain.dart`.
- **Una carpeta por página.** `pages/<página>/` contiene la pantalla y una carpeta `components/` con los widgets que solo usa esa página. Los widgets que comparten varias páginas de la feature van en `presentation/widgets/`.
- **Una carpeta por BLoC o Cubit.** `bloc/<nombre>/` contiene el bloc (o cubit) y su state, más el event en el caso de un BLoC. Event y state son `part` del archivo principal, así que el barril solo exporta ese archivo.
- **`Inter` / `Impl`.** Los contratos terminan en `Inter` y sus implementaciones en `Impl`: repositorios, datasources, `NetworkInfo` y `UseCaseInter`.
- **Errores como valores.** La capa data lanza `Exception`s (`ServerException`, `NetworkException`, `CacheException`, `AuthException`…). El repositorio las convierte en `Failure`s y devuelve `Either<Failure, T>` (dartz), con los alias `FutureEither<T>` y `StreamEither<T>` de `core/type_defs`. Los casos de uso implementan `UseCaseInter<T, Params>`, `UseCaseInterStream<T, Params>` cuando emiten en el tiempo, o `UseCaseInterSync<T, Params>` cuando devuelven un valor inmediato que no puede fallar. `AuthException` y `AuthFailure` aceptan un `code` opcional, y `ValidationFailure` uno obligatorio (de `<feature>_error_codes.dart`), para mostrar mensajes traducidos.
- **Errores HTTP en un solo lugar.** Los datasources remotos envuelven solo la llamada a `ApiClient` y convierten el `DioException` con `toAppException()` (`core/api/api_error.dart`): sin respuesta (sin conexión, timeout, DNS) es un `NetworkException`; con respuesta de error, un `ServerException` con su `statusCode` y el mensaje real del cuerpo (`message`, `error` o `detail`).
  ```dart
  final Response<dynamic> response;
  try {
    response = await apiClient.get(SongsEndpoints.base);
  } on DioException catch (e) {
    throw e.toAppException();
  }
  ```
- **Endpoints por feature.** Cada feature declara sus rutas en `data/datasources/remote/<feature>_endpoints.dart` (`SongsEndpoints.base`); `core/api` no conoce las rutas de ninguna feature.
- **Reloj e ids inyectables.** Los repositorios que guardan fechas o crean ids reciben `ClockInter` e `IdGeneratorInter` (por defecto `SystemClock` y `UuidIdGenerator`), así los tests los fijan.
- **Streams.** El datasource expone un `Stream` normal, y el repositorio lo convierte con `toEither`. Cada valor sale como `Right` y cada error como `Left` con su `Failure`, sin cerrar el stream:
  ```dart
  @override
  StreamEither<UserEntity?> userChanges() {
    final Stream<UserEntity?> users = remoteDataSource.userChanges();
    return users.toEither(_failureOf);
  }
  ```
  `toEither` funciona aunque el stream real sea de modelos (`Stream<UserModel>`) visto como de entidades, y mantiene la pausa, la cancelación y los streams *broadcast*.
- **Un caso de uso por archivo**, en `domain/usecases/`. Su clase de parámetros (`SignInParams`, …) puede ir en el mismo archivo.
- **Inyección de dependencias** con get_it. Cada feature registra lo suyo en `<feature>_injection.dart`:
  - BLoCs y Cubits como `registerFactory`, para que cada pantalla tenga su instancia.
  - Casos de uso, repositorios y datasources como `registerLazySingleton`.
  - Los contratos se registran con su tipo `Inter`.
- **TODOs** con el formato `TODO(<paquete-con-guiones>):`, por ejemplo `TODO(mi-app):`, porque el lint `flutter_style_todos` no acepta guiones bajos.

## Comandos

Todos se ejecutan en la raíz del proyecto Flutter, la carpeta que contiene `pubspec.yaml`. Salvo `init`, todos requieren que `init` ya se haya ejecutado.

Al terminar, los comandos ordenan los imports (`dart fix --code=directives_ordering`) y formatean los archivos que tocaron (`dart format`).

### Protecciones

Todos los comandos que cambian archivos tienen estas protecciones. `--dry-run` y `--allow-dirty` sirven en todos ellos, aunque las tablas de opciones de cada comando no los repitan:

| Protección | Cómo funciona |
|---|---|
| **Deshacer si algo falla** | La CLI registra cada archivo que toca. Si el comando falla a mitad de camino (un paso devuelve error, falla `flutter pub get`, `dart format` encuentra un error de sintaxis…), restaura todos esos archivos y avisa: «se deshicieron sus cambios en N archivos, el proyecto quedó como estaba». |
| **`--dry-run`** | Simula el comando sin escribir nada y lista qué archivos crearía, modificaría o eliminaría, y qué comandos (`flutter pub get`, `dart format`…) ejecutaría. |
| **Cambios sin commit** | `remove`, `rename`, `auth` y cualquier comando con `--force` se detienen si el repositorio git del proyecto tiene cambios sin commit, para que siempre puedas deshacer con git. `--allow-dirty` continúa igualmente. Si el proyecto no está en un repositorio git, solo muestra un aviso. |

```text
$ flutter_clean_arch feature albums --dry-run
(--dry-run) Simulación: no se escribirá nada.
…
(--dry-run) No se cambió nada. Esto es lo que haría:

Crearía (37):
  • lib/features/albums/albums.dart
  …
Modificaría (3):
  • lib/core/di/injection_container.dart
  • lib/core/router/app_router.dart
  • lib/core/router/app_routes.dart

Ejecutaría (2):
  • dart fix --apply --code=directives_ordering lib
  • dart format lib/features/albums lib/core
```

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | Terminó bien (o `--dry-run` sin errores) |
| `1` | Error del proyecto o de un paso: no es un proyecto Flutter, falta `init`, ya existe lo que quieres crear, `doctor` encontró problemas, falló un comando externo, hay cambios sin commit… |
| `64` | Error de uso: comando, opción o argumentos incorrectos (ver [Errores de uso](#errores-de-uso)) |

Si el código no es `0`, los cambios del comando se deshacen. La excepción es `doctor --fix`, que conserva lo que corrigió aunque queden otros problemas.

### `flutter_clean_arch init`

Crea la base del proyecto (64 archivos, ver [Estructura generada](#después-de-init)). Además:

- Borra `lib/main.dart` y `test/widget_test.dart` si siguen siendo los de `flutter create`.
- En `pubspec.yaml` añade `flutter_localizations` y `flutter: generate: true`.
- Configura los flavors de Android `development`, `staging` y `production` en `android/app/build.gradle.kts`:
  - Cada flavor tiene su sufijo de ID (`.dev`, `.stg`) y su nombre (`[DEV]`, `[STG]`), así se pueden instalar los tres a la vez.
  - En `AndroidManifest.xml` pone `android:label="${appName}"`.
  - Si el proyecto no tiene carpeta `android/`, este paso se omite.
- Agrega las dependencias a `pubspec.yaml` con versiones probadas (ver [Versiones de las dependencias](#versiones-de-las-dependencias)) y ejecuta `flutter pub get`.
- Ejecuta `flutter gen-l10n`.
- Crea `.flutter_clean_arch.yaml`, que guarda la versión de la CLI con la que se creó el proyecto.

#### Versiones de las dependencias

`init` y `auth` no instalan «la última versión» de cada paquete, sino rangos probados con el test de punta a punta. Así, una versión nueva e incompatible de un paquete no rompe los proyectos que generes. Si el proyecto ya declara un paquete, se respeta su versión.

| Paquete | Versión | | Paquete (dev) | Versión |
|---|---|---|---|---|
| dio | ^5.11.1 | | bloc_test | ^10.0.0 |
| get_it | ^9.3.0 | | mocktail | ^1.0.5 |
| dartz | ^0.10.1 | | very_good_analysis | ^10.3.0 |
| equatable | ^2.1.0 | | bloc_lint | ^0.4.1 |
| bloc | ^9.2.1 | | | |
| flutter_bloc | ^9.1.1 | | **auth** | |
| go_router | ^18.0.2 | | firebase_core | ^4.15.0 |
| internet_connection_checker | ^3.0.1 | | firebase_auth | ^6.7.0 |
| intl | ^0.20.2 | | google_sign_in | ^7.2.0 |
| uuid | ^4.6.0 | | | |

Para actualizar a una versión mayor en tu proyecto, cambia el rango en `pubspec.yaml`, ejecuta `flutter pub get` y luego `flutter analyze` y `flutter test`. Para actualizarla en la CLI, edita `initDependencies` (en `lib/src/commands/init_command.dart`) o `authDependencies` y ejecuta `dart test test_e2e`.

| Opción | Efecto |
|---|---|
| `-f`, `--force` | Sobrescribe los archivos que ya existan. Sin esta opción, si alguno existe, lista los conflictos y se detiene sin escribir nada. |
| `--no-pub` | Solo crea los archivos: no agrega dependencias ni genera l10n. |
| `--auth` | Agrega también la autenticación con Firebase, igual que [`auth`](#flutter_clean_arch-auth). |

```bash
flutter_clean_arch init --force
flutter run --flavor development -t lib/main_development.dart
```

iOS no tiene flavors automáticos: para usar `--flavor` en iOS hay que crear los esquemas en Xcode.

### `flutter_clean_arch auth`

Agrega login con Firebase (email/contraseña y Google) a un proyecto inicializado. Para un proyecto nuevo, usa `init --auth`, que hace lo mismo.

Crea:
- **La feature `lib/features/auth/`**, con la misma estructura que el resto de features:
  - `UserEntity` y los códigos de error `AuthErrorCodes`.
  - El repositorio y un datasource remoto con `firebase_auth` y `google_sign_in`.
  - 7 casos de uso: iniciar sesión con email y con Google, registrarse, recuperar contraseña, cerrar sesión, observar el usuario y obtener el usuario actual.
  - Los BLoCs `auth`, `login`, `register` y `forgot_password`.
  - Las páginas `login`, `register` y `forgot_password`, que validan con el mixin `Validator` y muestran los errores traducidos.
- **Sus tests** en `test/features/auth/`: repositorio, mapeo de errores de Firebase, BLoCs `auth` y `login`, y página de login.
- **`lib/core/firebase/`**: `AppFlavor` y `firebaseOptionsFor(flavor)`, más tres archivos provisionales `firebase_options_<flavor>.dart` que se reemplazan con FlutterFire. Si ya existen, no se tocan.

Modifica:

| Archivo | Cambio |
|---|---|
| `lib/bootstrap.dart` | Recibe `firebaseOptions` y llama a `Firebase.initializeApp` antes del DI |
| `lib/main_<flavor>.dart` | Pasa `firebaseOptionsFor(AppFlavor.<flavor>)` |
| `core/di/injection_container.dart` | `initDependencies({required firebaseOptions})` y `await initAuthDependencies(...)` |
| `core/router/app_routes.dart` | `login` (`/login`), `register` y `forgotPassword` (anidadas) e `isAuthRoute` |
| `core/router/app_router.dart` | Sin sesión redirige a `/login` y con sesión a `/home` (`refreshListenable` sobre el `AuthBloc`); rutas de auth |
| `app/pages/app.dart` | `BlocProvider.value(getIt<AuthBloc>())` alrededor de `MaterialApp.router` |
| `home/…/home_page.dart` | Botón de cerrar sesión en la AppBar |
| `core/l10n/arb/app_en.arb`, `app_es.arb` | 35 claves de auth (textos de pantallas y errores) |

Además agrega `firebase_core`, `firebase_auth` y `google_sign_in` a `pubspec.yaml` con versiones probadas (ver [Versiones de las dependencias](#versiones-de-las-dependencias)), y ejecuta `flutter pub get` y `flutter gen-l10n`. Cada edición es idempotente: si ya está hecha la omite, y si no encuentra el código esperado (porque lo modificaste) muestra qué cambiar a mano.

| Opción | Efecto |
|---|---|
| `-f`, `--force` | Reinstala la feature auth aunque ya exista (las ediciones ya hechas no se repiten). |
| `--no-pub` | No agrega dependencias ni genera l10n. |

Al terminar, la CLI muestra los siguientes pasos con los comandos exactos para tu proyecto:

1. Crear un proyecto de Firebase por flavor y habilitar **Email/Password** y **Google** en Authentication.
2. Generar las opciones de cada flavor con FlutterFire (los package ids salen de `build.gradle.kts`):
   ```bash
   flutterfire configure --yes --project=<proyecto-development> --platforms=android,ios \
     --out=lib/core/firebase/firebase_options_development.dart \
     --android-package-name=com.example.mi_app.dev --ios-bundle-id=com.example.mi_app.dev \
     --android-out=android/app/src/development/google-services.json \
     --ios-out=ios/config/development/GoogleService-Info.plist
   ```
   Repite con `staging` (`.stg`) y `production` (sin sufijo).
3. Android: registrar los SHA-1 y SHA-256 de tu keystore en cada app de Firebase (`cd android && ./gradlew signingReport`).
4. iOS: añadir el `REVERSED_CLIENT_ID` de cada `GoogleService-Info.plist` a `CFBundleURLTypes` en `ios/Runner/Info.plist`.

Hasta completar el paso 2, la app compila, pero al arrancar lanza un error que indica qué comando de FlutterFire ejecutar.

### `flutter_clean_arch feature <nombre>`

Crea `lib/features/<nombre>/` con 37 archivos, ver [Una feature](#una-feature-feature-songs):

- Entidad, modelo y datasources local y remoto (`Inter`/`Impl`), con soporte offline: si no hay conexión, el repositorio lee la caché.
- Repositorio (`Inter`/`Impl`) y el caso de uso `Get<Nombre>UseCaseImpl`.
- BLoC en `presentation/bloc/<nombre>/`.
- Página en `presentation/pages/<nombre>/` con `components/` (incluye `<Nombre>ErrorView`).
- `presentation/widgets/` con un widget de ejemplo.

También la registra en el resto del proyecto:

| Archivo | Qué agrega |
|---|---|
| `core/di/injection_container.dart` | El import de la feature y la llamada `init<Nombre>Dependencies()` |
| `core/router/app_routes.dart` | `AppRoutes.<nombre>` (`/<nombre>`) y `AppRoutes.<nombre>Name` |
| `core/router/app_router.dart` | El import y la `GoRoute` hacia `<Nombre>Page` |

| Opción | Efecto |
|---|---|
| `-f`, `--force` | Regenera la feature aunque exista, sin duplicar los registros. |
| `--no-route` | No agrega la ruta (para features sin pantalla propia). |
| `--tests` | Genera también sus tests, igual que [`test`](#flutter_clean_arch-test-feature). |

```bash
flutter_clean_arch feature user_profile
# Navega con: context.goNamed(AppRoutes.userProfileName)
```

### `flutter_clean_arch page <feature> <nombre>`

Agrega una página a una feature existente. También funciona con `home`.

- Crea `presentation/pages/<nombre>/` con `<nombre>_page.dart`, `components/` y sus barriles.
- La exporta en `pages/pages.dart`.
- Registra la ruta `AppRoutes.<feature><Nombre>` con el path `/<feature>/<nombre>`.

| Opción | Efecto |
|---|---|
| `--bloc` | Crea también un BLoC con el mismo nombre (igual que `bloc`). La página lo provee con `BlocProvider` y su vista reacciona a los estados. |
| `--tests` | Genera el test de la página (con `--bloc`, el de su vista con un `MockBloc` y el del BLoC) en `test/features/<feature>/presentation/…`. |
| `--no-route` | No agrega la ruta (por ejemplo, para una página que se abre como diálogo). |
| `-f`, `--force` | Vuelve a generar la página aunque exista. Conserva los exports de sus componentes en `components.dart`. |

```bash
flutter_clean_arch page songs song_detail --bloc
```

```text
presentation/
├─ bloc/song_detail/        song_detail.dart, song_detail_bloc.dart, _event.dart, _state.dart
└─ pages/song_detail/       song_detail.dart, song_detail_page.dart, components/components.dart
```

```dart
context.goNamed(AppRoutes.songsSongDetailName); // path /songs/song_detail
```

Errores posibles:
- La carpeta ya existe: usa `--force`.
- `AppRoutes.<constante>` ya existe: usa `--no-route` o elige otro nombre.

### `flutter_clean_arch bloc <feature> <nombre>`

Agrega un BLoC en `presentation/bloc/<nombre>/`:

- `<nombre>_bloc.dart` con el handler de `<Nombre>Started`.
- `<nombre>_event.dart`.
- `<nombre>_state.dart` con los estados `Initial`, `Loading`, `Loaded` y `Error`.
- El barril `<nombre>.dart`.

Además lo exporta en `bloc/bloc.dart` y lo registra con `registerFactory` en `<feature>_injection.dart`.

| Opción | Efecto |
|---|---|
| `--cubit` | Crea un Cubit (con su método `load()`) y su state, en lugar de un BLoC. |
| `--tests` | Genera `test/features/<feature>/presentation/bloc/<nombre>/<nombre>_bloc_test.dart` (o `_cubit_test.dart`) con `bloc_test`: estado inicial y la transición del evento o método de ejemplo. |
| `-f`, `--force` | Sobrescribe la carpeta si ya existe. |

```bash
flutter_clean_arch bloc songs player
flutter_clean_arch bloc songs filters --cubit
```

```dart
// songs_injection.dart
..registerFactory(PlayerBloc.new)
..registerFactory(FiltersCubit.new)
```

El BLoC se crea sin casos de uso. Para usar uno, agrégalo al constructor y actualiza su registro, por ejemplo `() => PlayerBloc(getSongs: getIt())`.

> `home` no tiene `home_injection.dart`. En ese caso el comando crea el BLoC y muestra la línea de registro para que la pegues a mano.

### `flutter_clean_arch usecase <feature> <nombre>`

Agrega un caso de uso a una feature que tenga capa `domain/`:

| Archivo | Cambio |
|---|---|
| `domain/usecases/<nombre>.dart` | Nuevo: `<Nombre>UseCaseImpl implements UseCaseInter<R, P>` |
| `domain/usecases/usecases.dart` | `export '<nombre>.dart';` |
| `domain/repositories/<feature>_repository_inter.dart` | Firma del método `<nombre>` |
| `data/repositories/<feature>_repository_impl.dart` | Stub con `@override` y `UnimplementedError` |
| `<feature>_injection.dart` | `registerLazySingleton(() => <Nombre>UseCaseImpl(repository: getIt()))` |

| Opción | Efecto |
|---|---|
| `--returns <tipo>` | Tipo que devuelve en caso de éxito. Por defecto `Unit`. |
| `--params <tipo>` | Tipo de los parámetros. Por defecto `NoParams`, y entonces el método del repositorio no recibe argumentos. |
| `--tests` | Genera `test/features/<feature>/domain/usecases/<nombre>_test.dart`: el caso de uso devuelve el resultado del repositorio y propaga sus fallos. Si `--returns` o `--params` es una clase de tu proyecto, el test que necesita un valor de ella queda en `skip` con un TODO para que lo completes. |
| `-f`, `--force` | Sobrescribe el archivo si ya existe. |

Ejemplo, buscar canciones por texto:

```bash
flutter_clean_arch usecase songs search_songs --returns "List<SongsEntity>" --params String
```

```dart
// domain/usecases/search_songs.dart
class SearchSongsUseCaseImpl implements UseCaseInter<List<SongsEntity>, String> {
  SearchSongsUseCaseImpl({required this.repository});

  final SongsRepositoryInter repository;

  @override
  FutureEither<List<SongsEntity>> call(String params) {
    return repository.searchSongs(params);
  }
}

// domain/repositories/songs_repository_inter.dart
FutureEither<List<SongsEntity>> searchSongs(String params);

// data/repositories/songs_repository_impl.dart
@override
FutureEither<List<SongsEntity>> searchSongs(String params) async {
  // TODO(mi-app): Implement search songs.
  throw UnimplementedError();
}
```

Después:
1. Implementa el método en el `Impl`, usando los datasources como hace `getSongs`.
2. Inyecta el caso de uso en el BLoC que lo use y actualiza su registro.

Más ejemplos:

| Caso | Comando | Resultado |
|---|---|---|
| Sin parámetros ni resultado | `usecase songs clear_cache` | `UseCaseInter<Unit, NoParams>`, método `clearCache()` |
| Borrar por id | `usecase songs delete_song --params String` | `deleteSong(String params)` → `Unit` |
| Guardar una entidad | `usecase songs save_song --params SongsEntity` | `saveSong(SongsEntity params)` |
| Varios parámetros | Crea una clase `SearchParams` en `domain/` y usa `--params SearchParams` | |

### `flutter_clean_arch component <feature> <página> <nombre>`

Crea un widget en `pages/<página>/components/<nombre>.dart` y lo exporta en `components.dart`. Úsalo para las piezas que solo usa esa página. La página tiene que existir.

```bash
flutter_clean_arch component songs song_detail cover
# → lib/features/songs/presentation/pages/song_detail/components/cover.dart (class Cover)
```

| Opción | Efecto |
|---|---|
| `-f`, `--force` | Sobrescribe el archivo si ya existe. |

### `flutter_clean_arch widget <feature> <nombre>`

Crea un widget en `presentation/widgets/<nombre>.dart` y lo exporta en `widgets.dart`. Úsalo para widgets que comparten varias páginas de la feature.

```bash
flutter_clean_arch widget songs song_tile
# → lib/features/songs/presentation/widgets/song_tile.dart (class SongTile)
```

| Opción | Efecto |
|---|---|
| `-f`, `--force` | Sobrescribe el archivo si ya existe. |

`component` y `widget` rechazan nombres que taparían un widget de Flutter (`card`, `text`, `icon`…). Usa uno más específico, como `song_card`.

### `flutter_clean_arch model <feature> <nombre> --from-json <archivo>`

Genera la entidad (`domain/entities/<nombre>_entity.dart`) y el modelo (`data/models/<nombre>_model.dart`) a partir de un JSON de ejemplo, por ejemplo una respuesta real de la API, y los exporta en sus barriles.

Cómo infiere los tipos:

| JSON | Dart |
|---|---|
| `"texto"` | `String` |
| `"2024-05-01"`, `"2024-05-01T10:00:00Z"` | `DateTime` (`DateTime.parse` / `toIso8601String`) |
| `7` / `4.5` | `int` / `double` (si en una lista hay enteros y decimales, `double`) |
| `true` | `bool` |
| `{ … }` | Una entidad y un modelo propios, con el nombre de la clave: `album` → `AlbumEntity` / `AlbumModel` |
| `[{ … }]` | `List<XEntity>`, con la clave en singular: `artists` → `ArtistEntity`, `categories` → `CategoryEntity` |
| `["a", "b"]` | `List<String>` (igual con números y booleanos) |
| `null`, `[]` | `dynamic` |

- Las claves pasan a camelCase (`released_at` → `releasedAt`) y en el JSON se mantiene la original. Si una clave es una palabra reservada, se le añade `Value` (`class` → `classValue`).
- Si el JSON es una lista, se combinan todos sus elementos. Un campo que falta o vale `null` en alguno es nullable, y los objetos anidados también se combinan.
- La entidad extiende `Equatable`. El modelo extiende la entidad y tiene `fromJson`, `toJson` y `fromEntity` (lo usa `toJson` para los objetos anidados).

Ejemplo con `song.json`:

```json
[
  { "id": 7, "title": "Blue Train", "rating": 4.5, "released_at": "1957-09-15",
    "cover_url": null, "album": { "id": "a1", "name": "Blue Train" },
    "artists": [{ "id": "ar1", "name": "John Coltrane" }], "genres": ["jazz"] },
  { "id": 8, "title": "Moment's Notice", "rating": 4, "released_at": "1957-09-15",
    "cover_url": "https://example.com/c.png", "album": { "id": "a1", "name": "Blue Train" },
    "artists": [{ "id": "ar1", "name": "John Coltrane", "role": "sax" }], "genres": [] }
]
```

```bash
flutter_clean_arch model songs song --from-json song.json
```

```dart
class SongEntity extends Equatable {
  const SongEntity({
    required this.id,
    required this.title,
    required this.rating,
    required this.releasedAt,
    required this.album,
    required this.artists,
    required this.genres,
    this.coverUrl,
  });

  final int id;
  final String title;
  final double rating;
  final DateTime releasedAt;
  final String? coverUrl;               // null en el primer elemento
  final AlbumEntity album;
  final List<ArtistEntity> artists;     // ArtistEntity incluye role (String?)
  final List<String> genres;
  …
}
```

| Opción | Efecto |
|---|---|
| `--from-json <archivo>` | Obligatorio. Archivo con un objeto JSON o una lista de objetos. |
| `--nullable` | Hace nullable todos los campos. |
| `-f`, `--force` | Sobrescribe las entidades y modelos que ya existan. |

Si `<nombre>` es el de la feature, se reemplazan la entidad y el modelo que creó `feature`. En ese caso, revisa el widget y los tests que usaban sus campos anteriores, por ejemplo `id`.

### `flutter_clean_arch test <feature>`

Genera en `test/features/<feature>/` los tests de lo que crea `feature`:

| Test | Comprueba |
|---|---|
| `domain/usecases/get_<feature>_test.dart` | El caso de uso devuelve lo que le da el repositorio (`Right` y `Left`) |
| `data/repositories/<feature>_repository_impl_test.dart` | Con conexión devuelve los datos remotos y los guarda en caché, y convierte `ServerException` y `NetworkException` en failures. Sin conexión lee la caché y convierte `CacheException` |
| `presentation/bloc/<feature>/<feature>_bloc_test.dart` | Estado inicial, `Loading → Loaded` y `Loading → Error` (bloc_test) |
| `presentation/pages/<feature>/<feature>_page_test.dart` | La vista muestra el indicador de carga, los datos y el error, y el botón de reintentar envía el evento (`MockBloc` + `pumpApp`) |

```bash
flutter_clean_arch test songs
flutter test test/features/songs
```

| Opción | Efecto |
|---|---|
| `-f`, `--force` | Sobrescribe los tests si ya existen. |

Solo sirve para la estructura que genera `feature`: necesita `Get<Feature>UseCaseImpl`, `<Feature>Bloc`, etc. Si cambias la entidad o el modelo (por ejemplo con `model`), ajusta los tests a los campos nuevos. Para lo que agregues después, usa la opción `--tests` de `page`, `bloc` y `usecase`.

### `flutter_clean_arch rename`

Renombra algo generado y todo lo que lo referencia. Tiene tres subcomandos:

```bash
flutter_clean_arch rename feature songs tracks
flutter_clean_arch rename page tracks song_detail track_info
flutter_clean_arch rename bloc tracks player audio_player
```

- **Dentro de la carpeta que se renombra**: renombra la carpeta, los archivos y todas las formas del nombre. Por ejemplo `song_detail`, `SongDetail`, `songDetail`, `Song detail` y `song detail` pasan a `track_info`, `TrackInfo`, `trackInfo`, `Track info` y `track info`. En los nombres de una sola palabra, el contexto decide la forma: en rutas y archivos se usa snake, en código camel o Pascal, y en comentarios las palabras.
- **En el resto de `lib/` y `test/`**: actualiza los imports, el export del barril padre, las clases declaradas en esa carpeta (con `\b`, así que `SongsBloc` no toca `SongBloc`), el registro en el DI, y las constantes, paths y nombres de `AppRoutes`.
- Las clases declaradas fuera de la carpeta conservan su nombre. Por ejemplo, al renombrar una página creada con `--bloc`, su BLoC sigue llamándose igual. Renómbralo aparte con `rename bloc`.
- Al terminar, ejecuta las comprobaciones de `doctor` y muestra cualquier problema. Revisa a mano los textos visibles (títulos, l10n).

| Opción | Efecto |
|---|---|
| `-y`, `--yes` | Aplica los cambios sin preguntar. |
| `--dry-run` | Solo muestra la lista de cambios. |
| `--allow-dirty` | Continúa aunque el repositorio git tenga cambios sin commit (ver [Protecciones](#protecciones)). |

Sin `--yes`, muestra la lista de cambios y pregunta `¿Aplicar estos cambios? (s/N)`. Si no hay una terminal interactiva (en un script o en CI), se cancela y pide usar `--yes`. No se puede renombrar `home`, ni usar un nombre que ya exista.

### `flutter_clean_arch remove`

Elimina algo generado y deshace sus registros. Tiene cuatro subcomandos:

| Subcomando | Elimina |
|---|---|
| `remove feature <feature>` | `lib/features/<feature>/`, `test/features/<feature>/`, su import y `init<Feature>Dependencies()` del DI, y las rutas de todas sus páginas |
| `remove page <feature> <página>` | La carpeta de la página, su export, su ruta (`GoRoute` y constantes de `AppRoutes`) y sus tests |
| `remove bloc <feature> <nombre>` | La carpeta del BLoC o Cubit, su export, su `registerFactory` y sus tests |
| `remove usecase <feature> <nombre>` | El archivo, su export, su registro en el DI, su método en el repositorio (`Inter` e `Impl`) y su test |

```text
$ flutter_clean_arch remove page songs song_detail --dry-run
(--dry-run) Simulación: no se escribirá nada.

Cambios:
  • Eliminar lib/features/songs/presentation/pages/song_detail
  • lib/features/songs/presentation/pages/pages.dart: quitar export
  • lib/core/router/app_router.dart: quitar la ruta de SongDetailPage
  • lib/core/router/app_routes.dart: quitar AppRoutes.songsSongDetail

(--dry-run: no se cambió nada)
```

Tiene las mismas opciones `--yes`, `--dry-run` y `--allow-dirty` que `rename`, y la misma confirmación. Al terminar, avisa de los archivos que todavía usan alguna clase eliminada, por ejemplo una página que usaba el BLoC borrado. La feature `home` no se puede eliminar.

### `flutter_clean_arch doctor`

Revisa el proyecto. Termina con código 0 si todo está bien y con 1 si encuentra problemas. Comprueba:

1. **Barriles**: cada carpeta de `lib/` con archivos Dart tiene `<carpeta>/<carpeta>.dart`. Se ignoran `lib/` y `lib/core/l10n/gen/`.
2. **Exports**: cada barril exporta los archivos de su carpeta y los barriles de sus subcarpetas. Acepta rutas relativas y `package:`. No exige exportar los `part of` ni el código generado (`firebase_options*.dart`, `*.g.dart`, `*.freezed.dart`…, o archivos con «GENERATED CODE» o «DO NOT EDIT» en la cabecera).
3. **Marcadores** de `injection_container.dart`, `app_router.dart` y `app_routes.dart`.
4. **Registro**: cada feature con `<feature>_injection.dart` se llama desde `initDependencies()`.
5. **Versión**: que exista `.flutter_clean_arch.yaml` y que el proyecto no se haya modificado con una versión de la CLI más nueva que la instalada (si es así, pide actualizarla). Si la CLI es más nueva que la última que tocó el proyecto, muestra un aviso con el enlace al CHANGELOG.

| Opción | Efecto |
|---|---|
| `--fix` | Crea los barriles y exports que faltan (puntos 1 y 2) y `.flutter_clean_arch.yaml` si no existe, formatea y vuelve a revisar. Los marcadores, registros y la versión de la CLI (puntos 3 a 5) se corrigen a mano. |

```text
$ flutter_clean_arch doctor

2 problemas:

Barriles que faltan:
  • Falta el barril lib/features/songs/presentation/pages/edit/edit.dart (components/components.dart, edit_page.dart)

Exports que faltan:
  • lib/core/utils/utils.dart no exporta 'extra.dart'

Ejecuta `flutter_clean_arch doctor --fix` para corregir los que se pueden arreglar solos.
```

`doctor --fix --dry-run` muestra qué corregiría sin cambiar nada.

## Nombres válidos

Las features, páginas, BLoCs y casos de uso aceptan `snake_case`, `kebab-case`, `camelCase` o `PascalCase`. `user_profile`, `user-profile`, `userProfile` y `UserProfile` generan lo mismo:

| Uso | Forma | Ejemplo |
|---|---|---|
| Archivos, carpetas y paths de ruta | snake | `user_profile` |
| Clases | Pascal | `UserProfileBloc` |
| Miembros | camel | `AppRoutes.userProfile` |

Reglas:
- Deben empezar por una letra y solo llevar letras, números y guiones bajos.
- No pueden ser palabras reservadas de Dart (`class`, `switch`…).
- Una feature nueva no puede llamarse `app`, `core` ni `home`, porque esos nombres los usa la estructura base. Sí se pueden usar como feature de destino o como nombre de página, BLoC o caso de uso, por ejemplo `page home about`.

## Marcadores

Los comandos insertan código justo antes de estos comentarios. No los borres:

| Marcador | Archivo | Lo usa |
|---|---|---|
| `// flutter_clean_arch:feature-imports` | `core/di/injection_container.dart`, `core/router/app_router.dart` | `feature`, `page` |
| `// flutter_clean_arch:feature-init` | `core/di/injection_container.dart` | `feature` |
| `// flutter_clean_arch:routes` | `core/router/app_routes.dart`, `core/router/app_router.dart` | `feature`, `page` |
| `// flutter_clean_arch:blocs` | `<feature>_injection.dart` | `bloc`, `page --bloc` |
| `// flutter_clean_arch:usecases` | `<feature>_injection.dart` | `usecase` |
| `// flutter_clean_arch:repository-methods` | `<feature>_repository_inter.dart`, `<feature>_repository_impl.dart` | `usecase` |

- Si falta un marcador, el comando no falla: avisa y muestra el código para pegarlo a mano.
- Para restaurar un marcador, vuelve a escribir la línea en su sitio: al final de la lista o cascada correspondiente, antes del `}` o `]` que la cierra.
- Las features creadas antes de que existieran los marcadores `blocs`, `usecases` y `repository-methods` no los tienen. Puedes añadirlos a mano para que `bloc` y `usecase` las actualicen solos.
- Insertar es idempotente: si el código ya está, no se duplica.

## Solución de problemas

| Síntoma | Solución |
|---|---|
| `flutter_clean_arch: command not found` | Agrega `%LOCALAPPDATA%\Pub\Cache\bin` al `PATH`. En Git Bash usa `flutter_clean_arch.bat`. |
| «Falta el comando: `--auth` es una opción de `init`» | Escribiste opciones sin el comando (ver [Errores de uso](#errores-de-uso)). Usa el que indica el mensaje, por ejemplo `flutter_clean_arch init --force --auth`. Si el proyecto ya tiene `init`, usa `flutter_clean_arch auth`. |
| «`help` solo recibe nombres de comandos» | Usa `help usecase` para ver todas sus opciones, incluida `--returns`. `help usecase --returns` no es válido. |
| `init`: «Estos archivos ya existen» | En un proyecto recién creado es `analysis_options.yaml`: usa `init --force`. En un proyecto con código, revisa la lista antes de forzar, porque se sobrescriben. |
| «No existe lib/core/di/injection_container.dart» | Ejecuta primero `flutter_clean_arch init`. |
| «La feature X no existe en lib/features» | Créala con `feature X` o revisa el nombre. |
| «No se encontró "// flutter_clean_arch:…"» | Pega el código que muestra el comando, o restaura el marcador (ver [Marcadores](#marcadores)). `doctor` lista los que faltan. |
| `auth`: «No se pudo editar … automáticamente» | Ese archivo ya no tiene el código que genera `init`. Aplica a mano el cambio que indica el mensaje. |
| La app con auth lanza «Firebase is not configured for the … flavor» | Falta ejecutar `flutterfire configure` para ese flavor (ver [`auth`](#flutter_clean_arch-auth)). |
| Google Sign-In falla en Android con `ApiException: 10` | Faltan los SHA-1/SHA-256 de tu keystore en la app de Firebase. |
| `remove`/`rename`: «Sin terminal interactiva» o «No se pudo leer la respuesta» | La consola no permite responder (scripts, CI o algunas terminales de Windows): revisa la lista con `--dry-run` y confirma con `--yes`. |
| `flutter pub get` termina con `PathNotFoundException … FlutterGeneratedPluginSwiftPackage` en Windows (en `init` o `auth`; sus cambios se deshacen) | Fallo de Flutter con rutas de más de 260 caracteres al preparar iOS. Mueve el proyecto a una ruta más corta o activa las rutas largas de Windows (`LongPathsEnabled`), y ejecuta `flutter pub get`. |
| `flutter run` falla con plugins en Windows | Activa el Modo de desarrollador. |
| `--flavor` no funciona en iOS | Crea los esquemas `development`, `staging` y `production` en Xcode. |
| `flutter analyze` muestra `sort_pub_dependencies` tras `init` | Es solo informativo: ordena alfabéticamente las dependencias del `pubspec.yaml`. |

## Modificar la CLI

Para cambiar lo que genera la CLI (por ejemplo, las plantillas de `lib/templates/`), agregar comandos o publicar versiones, instálala desde una copia local; así cada cambio se aplica sin reinstalar:

```bash
git clone https://github.com/andresbra23123/flutter_clean_arch_cli
dart pub global activate --source path flutter_clean_arch_cli
```

La estructura del código, las plantillas y sus variables, los tests, el CI y cómo publicar una versión están en [CONTRIBUTING.md](CONTRIBUTING.md).

## Licencia

[MIT](LICENSE). Puedes usar, copiar, modificar y distribuir la CLI, también con fines comerciales, manteniendo el aviso de copyright.
