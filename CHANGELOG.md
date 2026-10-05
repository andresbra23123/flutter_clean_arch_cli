# Changelog

Todos los cambios de la CLI `flutter_clean_arch`. Instala una versión concreta con
`dart pub global activate --source git https://github.com/andresbra23123/flutter_clean_arch_cli --git-ref v<versión>`.

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
