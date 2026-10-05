/// Pieces shared by the commands that add code to an existing project:
/// marker comments, registration snippets and the post-generation steps.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_clean_arch/src/injector.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/process_runner.dart';
import 'package:flutter_clean_arch/src/project.dart';

/// Marker comments placed by the `init` and `feature` templates.
abstract final class Markers {
  /// Imports of the feature barrels (DI container and router).
  static const featureImports = '// flutter_clean_arch:feature-imports';

  /// `init<Feature>Dependencies()` calls in the DI container.
  static const featureInit = '// flutter_clean_arch:feature-init';

  /// Route constants (`AppRoutes`) and `GoRoute`s (`AppRouter`).
  static const routes = '// flutter_clean_arch:routes';

  /// BLoC and Cubit registrations in `<feature>_injection.dart`.
  static const blocs = '// flutter_clean_arch:blocs';

  /// Use case registrations in `<feature>_injection.dart`.
  static const usecases = '// flutter_clean_arch:usecases';

  /// Methods of the feature repository (`Inter` and `Impl`).
  static const repositoryMethods = '// flutter_clean_arch:repository-methods';
}

/// Inserts [snippet] before [marker] in the project file [relative] and
/// reports the outcome. When the marker is missing, prints the snippet so
/// it can be pasted by hand.
InjectResult inject(
  FlutterProject project,
  String relative,
  String marker,
  String snippet,
) {
  final result = insertBeforeMarker(
    File(project.path(relative)),
    marker,
    snippet,
  );
  _report(result, relative, marker, snippet);
  return result;
}

/// Adds `export '[uri]';` to the barrel [relative] (creating it if needed)
/// and reports the outcome.
InjectResult registerExport(
  FlutterProject project,
  String relative,
  String uri,
) {
  final result = addExport(File(project.path(relative)), uri);
  switch (result) {
    case InjectResult.inserted:
      stdout.writeln('✓ Exportado en $relative.');
    case InjectResult.alreadyPresent:
      stdout.writeln('• Ya estaba exportado en $relative.');
    case InjectResult.markerNotFound:
      // addExport never returns it: it creates missing barrels.
      break;
  }
  return result;
}

void _report(
  InjectResult result,
  String relative,
  String marker,
  String snippet,
) {
  switch (result) {
    case InjectResult.inserted:
      stdout.writeln('✓ Registrado en $relative.');
    case InjectResult.alreadyPresent:
      stdout.writeln('• Ya estaba registrado en $relative.');
    case InjectResult.markerNotFound:
      stderr
        ..writeln(
          '! No se encontró "$marker" en $relative. '
          'Agrega esto a mano:',
        )
        ..writeln(snippet);
  }
}

/// `AppRoutes` constants for a page: `[constName]` with [path] and
/// `[constName]Name` with [routeName]. [title] goes in the section header
/// and [words] in the doc comments.
String routeConstants({
  required String constName,
  required String path,
  required String routeName,
  required String title,
  required String words,
}) {
  final header = '  // ── $title ';
  final rule = '─' * max(2, 62 - header.length);
  // The leading blank line separates it from the previous route block.
  return '''

$header$rule

  /// Path of the $words page.
  static const String $constName = '$path';

  /// Name of the $words route.
  static const String ${constName}Name = '$routeName';
''';
}

/// `GoRoute` entry for `AppRouter` that shows [pageClass] at
/// `AppRoutes.[constName]`.
String goRoute({required String constName, required String pageClass}) =>
    '''
      GoRoute(
        path: AppRoutes.$constName,
        name: AppRoutes.${constName}Name,
        pageBuilder: (context, state) => routerAnimation(
          page: const $pageClass(),
          animationType: RouterAnimationType.slide,
        ),
      ),''';

/// Import line of the barrel of [feature].
String featureBarrelImport(FlutterProject project, FeatureName feature) =>
    "import 'package:${project.package}/features/${feature.snake}/"
    "${feature.snake}.dart';";

/// Template variables shared by the commands that add an item ([item]) to
/// an existing [feature].
Map<String, String> itemVars(
  FlutterProject project,
  FeatureName feature,
  FeatureName item,
) => {
  'package': project.package,
  'todoTag': todoTagFromPackage(project.package),
  'feature': feature.snake,
  'Feature': feature.pascal,
  'name': item.snake,
  'Name': item.pascal,
  'nameCamel': item.camel,
  'nameTitle': item.title,
  'nameWords': item.lowerWords,
};

/// Sorts the directives and formats [paths]. Returns the first non-zero
/// exit code, or 0.
Future<int> runPostSteps(FlutterProject project, List<String> paths) async {
  // `dart fix` takes a single folder: sort the directives of `lib` (where
  // registrations land) and of every other top-level folder touched.
  final roots = {
    'lib',
    for (final path in paths) path.split('/').first,
  }.where((root) => Directory(project.path(root)).existsSync());
  for (final step in [
    for (final root in roots)
      ['fix', '--apply', '--code=directives_ordering', root],
    ['format', ...paths],
  ]) {
    final code = await runCommand(
      'dart',
      step,
      workingDirectory: project.root,
    );
    if (code != 0) return code;
  }
  return 0;
}

/// Parses the target feature [input] of `page`, `bloc` and `usecase`, and
/// checks that `lib/features/<feature>/` exists.
///
/// Throws a [FormatException] with a readable message otherwise.
FeatureName existingFeature(FlutterProject project, String input) {
  final feature = FeatureName.parse(input, allowTaken: true);
  if (!Directory(project.path('lib/features/${feature.snake}')).existsSync()) {
    throw FormatException(
      'La feature "${feature.snake}" no existe en lib/features. '
      'Créala con `flutter_clean_arch feature ${feature.snake}`.',
    );
  }
  return feature;
}

/// Parses `<feature> <name>` from [rest] for the commands that add or
/// change something inside a feature, and loads the project of the
/// current directory.
///
/// The arguments are checked first, so a wrong call gets its usage error
/// even outside a project. Calls [usageException] (which throws) when the
/// arguments are wrong or the feature does not exist, and throws a
/// [ProjectException] when the project is not initialized.
(FlutterProject, FeatureName, FeatureName) parseFeatureAndItem(
  List<String> rest,
  Never Function(String message) usageException, {
  required String example,
}) {
  if (rest.length != 2) {
    usageException('Indica la feature y el nombre, por ejemplo: $example');
  }
  final project = FlutterProject.load(Directory.current.path);
  if (!project.isInitialized) {
    throw const ProjectException(
      'No existe lib/core/di/injection_container.dart. '
      'Ejecuta primero `flutter_clean_arch init`.',
    );
  }
  try {
    return (
      project,
      existingFeature(project, rest[0]),
      FeatureName.parse(rest[1], allowTaken: true),
    );
  } on FormatException catch (e) {
    usageException(e.message);
  }
}
