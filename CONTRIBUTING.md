# Desarrollo de flutter_clean_arch CLI

Guía para modificar la CLI. Para usarla, mira el [README](README.md).

## Preparar el entorno

```bash
git clone https://github.com/andresbra23123/flutter_clean_arch_cli
cd flutter_clean_arch_cli
dart pub get

# Instala tu copia local: cada cambio se aplica sin reinstalar.
dart pub global activate --source path .
```

Necesitas Dart `^3.12.0`, y Flutter para el test de punta a punta. Tras un cambio, la primera ejecución muestra «Building package executable…» mientras se recompila.

## Estructura

```text
bin/flutter_clean_arch.dart     Punto de entrada: ejecuta CliRunner y muestra los errores
lib/flutter_clean_arch.dart     Exporta todo lib/src (lo usan bin/ y los tests)
lib/src/
├─ cli_runner.dart              CliRunner: registra los comandos, --version, y envuelve cada
│                               comando con el registro de cambios, --dry-run y el aviso de
│                               cambios sin commit; actualiza .flutter_clean_arch.yaml
├─ commands/                    Un archivo por comando (init, auth, feature, page, bloc,
│                               usecase, widget/component, model, test, rename, remove, doctor)
├─ journal.dart                 ChangeJournal: registra cada archivo tocado para deshacer o
│                               simular; readText / writeText / fileExists / deleteFile…
├─ generator.dart               TemplateGenerator: renderiza los .tmpl
├─ injector.dart                insertBeforeMarker, addExport y readExports
├─ registry.dart                Marcadores, snippets de rutas y DI, pasos finales (fix y format)
├─ dependencies.dart            addDependencies: escribe paquetes con versión en pubspec.yaml
├─ json_model.dart              modelsFromJson: entidades y modelos desde un JSON
├─ item_tests.dart              Tests de page, bloc y usecase (--tests)
├─ remover.dart                 Operaciones inversas (exports, DI, rutas, métodos) y ChangePlan
├─ renamer.dart                 planRename y replaceAllOnce
├─ auth_installer.dart          installAuth / applyAuthChanges
├─ doctor.dart                  diagnose y fixIssues
├─ project.dart                 FlutterProject: lee pubspec.yaml
├─ project_config.dart          .flutter_clean_arch.yaml y compareVersions
├─ version.dart                 cliVersion (del pubspec instalado) y changelogUrl
├─ usage_hints.dart             Mensajes de error de uso y traducción de la ayuda de args
├─ naming.dart                  FeatureName: snake, Pascal, camel…
├─ android_flavors.dart         Edición de build.gradle.kts y AndroidManifest.xml
└─ process_runner.dart          Ejecuta flutter y dart (en --dry-run solo los anota)
lib/templates/                  Plantillas .tmpl (ver más abajo)
test/                           Tests unitarios de cada pieza
test_e2e/                       Test de punta a punta
.github/workflows/ci.yml        CI: tests, test de punta a punta y Releases
```

## Plantillas

Están en `lib/templates/` como archivos `.tmpl`. Cualquier `.tmpl` nuevo dentro de una carpeta se genera automáticamente.

| Carpeta | La usa |
|---|---|
| `init/` | `init` |
| `feature/` | `feature` |
| `page/`, `page_bloc/` | `page` (`page_bloc/` reemplaza la página cuando se usa `--bloc`) |
| `bloc/`, `cubit/` | `bloc`, `bloc --cubit` |
| `usecase/` | `usecase` |
| `component/` | `component` y `widget` |
| `test_feature/` | `test` y `feature --tests` |
| `test_page/`, `test_page_bloc/`, `test_bloc/`, `test_cubit/` | `--tests` de `page` y `bloc` |
| `auth/`, `auth_l10n/` | `auth` e `init --auth` (`auth_l10n/` son las claves que se agregan a los ARB) |

`model` y el test de `usecase --tests` no usan plantillas: se generan con código (`json_model.dart` e `item_tests.dart`), porque dependen de los tipos.

Variables (`{{variable}}`):

| Variable | Disponible en | Ejemplo |
|---|---|---|
| `{{package}}` | todas | `mi_app` |
| `{{todoTag}}` | todas | `mi-app` |
| `{{appTitle}}` | `init`, `auth`, `auth_l10n` | `Mi App` |
| `{{name}}`, `{{Name}}`, `{{nameCamel}}`, `{{nameTitle}}`, `{{nameWords}}` | `feature` y `test_feature`: la feature. `page`, `bloc`, `cubit`, `usecase`, `component` y los `test_*` de `--tests`: el elemento creado | `song_detail`, `SongDetail`, `songDetail`, `Song detail`, `song detail` |
| `{{feature}}`, `{{Feature}}` | `page`, `bloc`, `cubit`, `usecase`, `component` y los `test_*` de `--tests` | `songs`, `Songs` |
| `{{returns}}`, `{{params}}`, `{{callArgs}}` | `usecase` | `Unit`, `NoParams`, vacío (con `NoParams`) o `params` |
| `{{kindDescription}}` | `component` | Descripción para el comentario de cabecera |

Reglas:
- `__name__` en el nombre de un archivo o carpeta se reemplaza por `{{name}}`.
- Un barril por carpeta (`<carpeta>/<carpeta>.dart`); los tests lo comprueban.
- Nombres genéricos (`mi_app`, `songs`, `com.example`…), nunca los de un proyecto real.
- El código generado tiene que pasar `flutter analyze` sin warnings con `very_good_analysis`; el test de punta a punta lo comprueba.

## Tests

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test            # tests unitarios (segundos)
dart test test_e2e   # punta a punta (unos 3 minutos; necesita Flutter y red)
```

El test de punta a punta crea un proyecto con `flutter create` en una carpeta temporal y, con la CLI de tu copia:
1. Comprueba que `init --dry-run` no cambia nada.
2. Ejecuta todos los comandos: `init --auth`, `feature --tests`, `page --bloc --tests`, `component`, `page --force` (conserva el componente), `widget`, `bloc --cubit --tests`, `usecase --tests` (dos variantes), `model --from-json`, `rename`, `remove`.
3. Provoca un fallo a mitad de un comando y comprueba que se deshace.
4. Comprueba `.flutter_clean_arch.yaml`, `doctor`, que `flutter analyze` no da errores ni warnings y que `flutter test` pasa.

Ejecútalo antes de publicar una versión; el CI también lo ejecuta en cada etiqueta.

## Agregar un comando

1. Crea sus plantillas en `lib/templates/<nombre>/`.
2. Crea `lib/src/commands/<nombre>_command.dart`, una clase que extiende `Command<int>`. Reutiliza `parseFeatureAndItem`, `itemVars`, `inject`, `registerExport` y `runPostSteps` de `registry.dart`. Si borra o modifica archivos existentes, usa `ChangePlan` con `addConfirmationFlags` y `confirmPlan`, como `remove` y `rename`.
3. Lee y escribe archivos solo con `readText`, `writeText`, `fileExists`, `deleteFile` y `deleteDirectory` (`journal.dart`), nunca con `File` directamente: así el comando se deshace si falla y funciona con `--dry-run`. Ejecuta comandos externos con `runCommand`.
4. Regístralo en `CliRunner` (`lib/src/cli_runner.dart`); este le agrega `--dry-run` y `--allow-dirty`. Exporta el archivo en `lib/flutter_clean_arch.dart`.
5. Valida los argumentos antes de leer el proyecto, con mensajes en español (`usageException`).
6. Agrega sus tests en `test/` y el comando al test de punta a punta.
7. Documéntalo en el README y en `CHANGELOG.md`.

## Actualizar las versiones de las dependencias

`init` y `auth` instalan rangos fijos (`initDependencies`, `initDevDependencies` en `lib/src/commands/init_command.dart` y `authDependencies` en `lib/src/auth_installer.dart`). Para subir una versión mayor: cambia el rango, ajusta las plantillas si hace falta, ejecuta `dart test test_e2e` y actualiza la tabla del README.

## CI (`.github/workflows/ci.yml`)

| Job | Cuándo | Qué hace |
|---|---|---|
| `check` | Cada push a `main`, cada pull request y a mano | En Windows, macOS y Linux: formato, `dart analyze --fatal-infos` y `dart test` |
| `e2e` | Cada etiqueta `v*` y a mano | En Linux con Flutter estable: `dart test test_e2e` |
| `release` | Cada etiqueta `v*`, si `check` y `e2e` pasaron | Comprueba que la etiqueta coincide con `version` de `pubspec.yaml` y publica el GitHub Release con la sección del CHANGELOG |

El resultado se ve en la pestaña **Actions** del repositorio. Para ejecutar el test de punta a punta sin crear una etiqueta: **Actions → CI → Run workflow**.

## Publicar una versión

1. Sube `version` en `pubspec.yaml` y añade su sección `## <versión>` al principio de `CHANGELOG.md`.
2. Haz commit, crea la etiqueta y súbela:
   ```bash
   git tag -a v0.2.0 -m "v0.2.0"
   git push origin main v0.2.0
   ```
3. El CI ejecuta los tests en los tres sistemas y el test de punta a punta y, si todo pasa, publica el Release. Si falla, corrige, haz commit y mueve la etiqueta:
   ```bash
   git push origin :refs/tags/v0.2.0
   git tag -d v0.2.0 && git tag -a v0.2.0 -m "v0.2.0"
   git push origin main v0.2.0
   ```
