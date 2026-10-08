# Changelog

Todos los cambios de la CLI `flutter_clean_arch`. Instala una versión concreta con
`dart pub global activate --source git https://github.com/andresbra23123/flutter_clean_arch_cli --git-ref v<versión>`.

## Sin publicar

- `core/type_defs`: `StreamEither<T>` y la extensión `toEither()`, que convierte un `Stream` en uno de `Either` (valores → `Right`, errores → `Left`, sin cerrar el stream). Funciona con streams de modelos vistos como de entidades.
- `core/usecases`: `UseCaseInterStream<T, Params>` para casos de uso que emiten en el tiempo.
- `UseCaseInter.call` devuelve `FutureEither<T>`, y lo mismo hacen los casos de uso, los repositorios de `feature` y los métodos que añade `usecase`, en vez de `Future<Either<Failure, T>>`. `usecase` agrega el import de `type_defs` al repositorio si falta (features creadas antes) y solo importa `dartz` en el caso de uso cuando el tipo lo usa (`Unit`, `Option`…).
- Los proyectos generados incluyen `test/core/type_defs/type_defs_test.dart`.
- `core/api`: `toAppException()` (`api_error.dart`) convierte un `DioException` en `NetworkException` (sin respuesta) o `ServerException` (con el `statusCode` y el mensaje real del cuerpo). `ApiInterceptor` solo registra en modo debug, con la duración de cada llamada. `ApiClient` acepta archivos multipart (`ApiFile`) en `post`/`put` y `queryParameters` en `delete`. Nuevo `ApiDateFormat`. Se elimina `api_endpoints.dart`: cada feature declara sus rutas en `data/datasources/remote/<feature>_endpoints.dart`.
- `core/utils`: `ClockInter`/`SystemClock` e `IdGeneratorInter`/`UuidIdGenerator` (nueva dependencia `uuid`). `AppUtils.formatDate` usa `intl`.
- `core/validation`: `ValidationRules`, reglas en Dart puro que usan tanto los casos de uso como el mixin `Validator` (un único regex de email).
- `core/network`: `NetworkInfoInter.onStatusChange`.
- `core/errors`: `ValidationFailure` con `code`. `core/usecases`: `UseCaseInterSync` y `NoParams` con constructor `const`.
- `feature`: `<feature>_endpoints.dart` y `domain/errors/<feature>_error_codes.dart`; el datasource remoto usa `toAppException()` y el repositorio convierte `NetworkException` en `NetworkFailure`.
- Los proyectos generados incluyen tests de `api_error`, `clock`, `id_generator` y `validation_rules`.
- Auth: `GetCurrentUserUseCaseImpl` implementa `UseCaseInterSync`.
- Auth: un caso de uso por archivo (`watch_user.dart` y `get_current_user.dart` reemplazan a `session_use_cases.dart`). `WatchUser` implementa `UseCaseInterStream` y el repositorio devuelve `StreamEither<UserEntity?>`. Los errores del stream de Firebase se convierten en `AuthFailure`, y el `AuthBloc` los reporta sin cerrar la sesión.

## 0.1.0

Primera versión.

**Comandos**
- `init`: base del proyecto (`core`, app, flavors de Android, l10n en/es, DI, `home` y página no encontrada). Con `--auth` incluye la autenticación.
- `auth`: login con Firebase (email + Google), redirección según la sesión, opciones de Firebase por flavor y sus tests.
- `feature` (`--tests`), `page` (`--bloc`, `--tests`), `bloc` (`--cubit`, `--tests`), `usecase` (`--returns`, `--params`, `--tests`), `component` y `widget`.
- `model --from-json`: entidades y modelos (`fromJson`, `toJson`, `fromEntity`) a partir de un JSON de ejemplo, con objetos anidados, listas, fechas y campos nullable.
- `test`: tests de una feature (caso de uso, repositorio, BLoC y página).
- `rename` y `remove` para features, páginas, BLoCs y casos de uso, con `--dry-run` y confirmación.
- `doctor` (`--fix`): barriles, marcadores, registros en el DI y versión de la CLI.
- `--version` y ayuda en español, con sugerencias para los errores de uso más comunes.

**Convenciones del código generado**
- Un barril por carpeta, una carpeta por página (con `components/`) y por BLoC, `Inter`/`Impl` y errores como `Either<Failure, T>`.

**Protección**
- Si un comando falla a mitad de camino, se deshacen todos sus cambios en archivos.
- `--dry-run` en todos los comandos que cambian archivos.
- `remove`, `rename`, `auth` y cualquier `--force` se detienen si el repositorio git tiene cambios sin commit (`--allow-dirty` para continuar).

**Versiones**
- `init` y `auth` instalan las dependencias con rangos de versión probados.
- Cada proyecto guarda en `.flutter_clean_arch.yaml` con qué versión de la CLI se creó y modificó.

**Calidad**
- CI en GitHub Actions (Windows, macOS y Linux), test de punta a punta y GitHub Release en cada etiqueta.
- Licencia MIT.
