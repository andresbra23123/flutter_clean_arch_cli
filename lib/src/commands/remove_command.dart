/// `flutter_clean_arch remove <feature|page|bloc|usecase>`: deletes what
/// the generators created and undoes its exports, DI registrations and
/// routes.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';
import 'package:flutter_clean_arch/src/remover.dart';
import 'package:path/path.dart' as p;

/// `remove`, the parent of the four subcommands.
class RemoveCommand extends Command<int> {
  /// Registers the subcommands.
  RemoveCommand() {
    addSubcommand(_RemoveFeature());
    addSubcommand(_RemovePage());
    addSubcommand(_RemoveBloc());
    addSubcommand(_RemoveUsecase());
  }

  @override
  String get name => 'remove';

  @override
  String get description =>
      'Elimina una feature, página, BLoC o use case y deshace sus exports, '
      'registros en el DI y rutas.';
}

/// Shared flow: build a [ChangePlan], list it, confirm, apply, report.
abstract class _RemoveSubcommand extends Command<int> {
  _RemoveSubcommand() {
    addConfirmationFlags(argParser);
  }

  /// Number of positional arguments (`<feature>` and maybe `<nombre>`).
  int get arity;

  /// Example shown when the arguments are wrong.
  String get example;

  /// Fills [plan] and returns the classes that will no longer exist.
  List<String> buildPlan(
    ChangePlan plan,
    FlutterProject project,
    FeatureName feature,
    FeatureName? item,
  );

  @override
  Future<int> run() async {
    final args = argResults!;
    final rest = args.rest;
    if (rest.length != arity) {
      usageException('Argumentos incorrectos. Ejemplo: $example');
    }
    final project = FlutterProject.load(Directory.current.path);
    final FeatureName feature;
    final FeatureName? item;
    try {
      if (!project.isInitialized) {
        throw const FormatException(
          'No existe lib/core/di/injection_container.dart. '
          'Ejecuta primero `flutter_clean_arch init`.',
        );
      }
      feature = existingFeature(project, rest[0]);
      item = arity == 2 ? FeatureName.parse(rest[1], allowTaken: true) : null;
    } on FormatException catch (e) {
      usageException(e.message);
    }

    final plan = ChangePlan(project);
    final removedClasses = buildPlan(plan, project, feature, item);
    if (plan.isEmpty) {
      stderr.writeln('No hay nada que eliminar.');
      return 1;
    }
    if (!confirmPlan(plan, args)) return (args['dry-run'] as bool) ? 0 : 1;

    plan.apply();
    stdout.writeln('✓ ${plan.descriptions.length} cambios aplicados.');
    final code = await runPostSteps(project, ['lib']);
    if (code != 0) return code;
    _warnLeftovers(project, removedClasses);
    return 0;
  }
}

class _RemoveFeature extends _RemoveSubcommand {
  @override
  String get name => 'feature';

  @override
  String get description =>
      'Elimina una feature completa, sus tests, su registro en el DI y sus '
      'rutas.';

  @override
  String get invocation => 'flutter_clean_arch remove feature <feature>';

  @override
  int get arity => 1;

  @override
  String get example => 'remove feature songs';

  @override
  List<String> buildPlan(
    ChangePlan plan,
    FlutterProject project,
    FeatureName feature,
    FeatureName? item,
  ) {
    if (feature.snake == 'home') {
      throw UsageException(
        'La feature home es parte de la estructura base y no se elimina.',
        usage,
      );
    }
    final root = 'lib/features/${feature.snake}';
    final classes = declaredClasses(project, root);
    final pageClasses = classes.where((c) => c.endsWith('Page')).toList();
    final import = featureBarrelImport(project, feature);

    plan
      ..delete(root)
      ..delete('test/features/${feature.snake}')
      ..edit(
        'lib/core/di/injection_container.dart',
        'quitar import e init${feature.pascal}Dependencies()',
        (s) => removeLines(
          s,
          (l) =>
              l.trim() == import ||
              l.trim().endsWith('init${feature.pascal}Dependencies();'),
        ),
      )
      ..edit(
        'lib/core/router/app_router.dart',
        'quitar import',
        (s) => removeLines(s, (l) => l.trim() == import),
      );
    for (final page in pageClasses) {
      planRouteRemoval(plan, page);
    }
    return classes;
  }
}

class _RemovePage extends _RemoveSubcommand {
  @override
  String get name => 'page';

  @override
  String get description => 'Elimina una página, su export y su ruta.';

  @override
  String get invocation => 'flutter_clean_arch remove page <feature> <página>';

  @override
  int get arity => 2;

  @override
  String get example => 'remove page songs song_detail';

  @override
  List<String> buildPlan(
    ChangePlan plan,
    FlutterProject project,
    FeatureName feature,
    FeatureName? item,
  ) {
    final pages = 'lib/features/${feature.snake}/presentation/pages';
    final dir = '$pages/${item!.snake}';
    final classes = declaredClasses(project, dir);
    plan
      ..delete(dir)
      ..delete('test${dir.substring(3)}')
      ..edit(
        '$pages/pages.dart',
        'quitar export',
        (s) => removeExport(s, '${item.snake}/${item.snake}.dart'),
      );
    for (final page in classes.where((c) => c.endsWith('Page'))) {
      planRouteRemoval(plan, page);
    }
    return classes;
  }
}

class _RemoveBloc extends _RemoveSubcommand {
  @override
  String get name => 'bloc';

  @override
  String get description =>
      'Elimina un BLoC o Cubit, su export y su registro en el DI.';

  @override
  String get invocation => 'flutter_clean_arch remove bloc <feature> <nombre>';

  @override
  int get arity => 2;

  @override
  String get example => 'remove bloc songs player';

  @override
  List<String> buildPlan(
    ChangePlan plan,
    FlutterProject project,
    FeatureName feature,
    FeatureName? item,
  ) {
    final blocs = 'lib/features/${feature.snake}/presentation/bloc';
    final dir = '$blocs/${item!.snake}';
    final classes = declaredClasses(project, dir);
    plan
      ..delete(dir)
      ..delete('test${dir.substring(3)}')
      ..edit(
        '$blocs/bloc.dart',
        'quitar export',
        (s) => removeExport(s, '${item.snake}/${item.snake}.dart'),
      );
    for (final cls in classes.where(
      (c) => c.endsWith('Bloc') || c.endsWith('Cubit'),
    )) {
      plan.edit(
        'lib/features/${feature.snake}/${feature.snake}_injection.dart',
        'quitar el registro de $cls',
        (s) => removeCascadeEntry(
          removeCascadeEntry(s, '$cls.new'),
          '$cls(',
        ),
      );
    }
    return classes;
  }
}

class _RemoveUsecase extends _RemoveSubcommand {
  @override
  String get name => 'usecase';

  @override
  String get description =>
      'Elimina un use case, su export, su registro en el DI y su método en '
      'el repositorio.';

  @override
  String get invocation =>
      'flutter_clean_arch remove usecase <feature> <nombre>';

  @override
  int get arity => 2;

  @override
  String get example => 'remove usecase songs delete_song';

  @override
  List<String> buildPlan(
    ChangePlan plan,
    FlutterProject project,
    FeatureName feature,
    FeatureName? item,
  ) {
    final root = 'lib/features/${feature.snake}';
    final file = '$root/domain/usecases/${item!.snake}.dart';
    final classes = declaredClasses(project, file);
    plan
      ..delete(file)
      ..delete(
        'test/features/${feature.snake}/domain/usecases/${item.snake}_test.dart',
      )
      ..edit(
        '$root/domain/usecases/usecases.dart',
        'quitar export',
        (s) => removeExport(s, '${item.snake}.dart'),
      );
    for (final cls in classes) {
      plan.edit(
        '$root/${feature.snake}_injection.dart',
        'quitar el registro de $cls',
        (s) => removeCascadeEntry(s, '$cls('),
      );
    }
    for (final repo in [
      '$root/domain/repositories/${feature.snake}_repository_inter.dart',
      '$root/data/repositories/${feature.snake}_repository_impl.dart',
    ]) {
      plan.edit(
        repo,
        'quitar el método ${item.camel}',
        (s) => removeMethod(s, item.camel),
      );
    }
    return classes;
  }
}

/// Plans removing the route of [pageClass] from `AppRouter` and its
/// constants from `AppRoutes`.
void planRouteRemoval(ChangePlan plan, String pageClass) {
  String? constant;
  plan.edit('lib/core/router/app_router.dart', 'quitar la ruta de $pageClass', (
    s,
  ) {
    final result = removeGoRoute(s, pageClass);
    constant = result.constant;
    return result.source;
  });
  final name = constant;
  if (name == null) return;
  plan.edit(
    'lib/core/router/app_routes.dart',
    'quitar AppRoutes.$name',
    (s) => removeRouteConstants(s, name),
  );
}

/// Classes, enums and mixins declared in the Dart files under [relative]
/// (a folder or a single file).
List<String> declaredClasses(FlutterProject project, String relative) {
  final path = project.path(relative);
  final files = FileSystemEntity.isDirectorySync(path)
      ? Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
      : [File(path)].where((f) => f.existsSync());
  final declaration = RegExp(
    r'^(?:abstract |sealed |final |base |interface )*(?:class|enum|mixin) (\w+)',
    multiLine: true,
  );
  return [
    for (final f in files)
      ...declaration.allMatches(f.readAsStringSync()).map((m) => m[1]!),
  ];
}

/// Adds `--yes` and `--dry-run` to a destructive command.
void addConfirmationFlags(ArgParser parser) {
  parser
    ..addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Aplica los cambios sin preguntar.',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Solo muestra los cambios, sin aplicarlos.',
    );
}

/// Lists [plan] and asks for confirmation. Returns whether to apply it.
bool confirmPlan(ChangePlan plan, ArgResults args) {
  stdout.writeln('Cambios:');
  for (final d in plan.descriptions) {
    stdout.writeln('  • $d');
  }
  if (args['dry-run'] as bool) {
    stdout.writeln('\n(--dry-run: no se cambió nada)');
    return false;
  }
  if (args['yes'] as bool) return true;
  if (!stdin.hasTerminal) {
    stderr.writeln('\nSin terminal interactiva: usa --yes para confirmar.');
    return false;
  }
  stdout.write('\n¿Aplicar estos cambios? (s/N) ');
  final String answer;
  try {
    answer = stdin.readLineSync()?.trim().toLowerCase() ?? '';
  } on StdinException {
    // Some Windows consoles report a terminal but cannot read from it.
    stderr.writeln('\nNo se pudo leer la respuesta: usa --yes para confirmar.');
    return false;
  }
  final ok = const {'s', 'si', 'sí', 'y', 'yes'}.contains(answer);
  if (!ok) stdout.writeln('Cancelado.');
  return ok;
}

/// Prints the files under `lib/` and `test/` that still mention one of
/// [classes].
void _warnLeftovers(FlutterProject project, List<String> classes) {
  if (classes.isEmpty) return;
  final pattern = RegExp('\\b(${classes.map(RegExp.escape).join('|')})\\b');
  final hits = <String>{};
  for (final folder in ['lib', 'test']) {
    final dir = Directory(project.path(folder));
    if (!dir.existsSync()) continue;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (pattern.hasMatch(file.readAsStringSync())) {
        hits.add(p.relative(file.path, from: project.root));
      }
    }
  }
  if (hits.isEmpty) return;
  stderr.writeln('\n! Estos archivos todavía usan lo eliminado; revísalos:');
  for (final hit in hits.toList()..sort()) {
    stderr.writeln('  • $hit');
  }
}
