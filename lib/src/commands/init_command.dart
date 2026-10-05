/// `flutter_clean_arch init`: creates the base structure of the project.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/android_flavors.dart';
import 'package:flutter_clean_arch/src/auth_installer.dart';
import 'package:flutter_clean_arch/src/dependencies.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/process_runner.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Runtime dependencies added by `init`, with the version ranges the
/// templates are tested with (`dart test test_e2e`). Pinned so a breaking
/// release of a package cannot break newly generated projects.
const initDependencies = [
  'dio:^5.11.1',
  'get_it:^9.3.0',
  'dartz:^0.10.1',
  'equatable:^2.1.0',
  'bloc:^9.2.1',
  'flutter_bloc:^9.1.1',
  'go_router:^18.0.2',
  'internet_connection_checker:^3.0.1',
  'intl:^0.20.2',
];

/// Dev dependencies added by `init`, pinned like [initDependencies].
const initDevDependencies = [
  'dev:bloc_test:^10.0.0',
  'dev:mocktail:^1.0.5',
  'dev:very_good_analysis:^10.3.0',
  'dev:bloc_lint:^0.4.1',
];

/// Files created by `flutter create` that break once `init` replaces
/// `MyApp`. They are deleted only if they still are the default ones.
const _flutterCreateDefaults = ['lib/main.dart', 'test/widget_test.dart'];

/// `init`: creates the base structure of the project.
class InitCommand extends Command<int> {
  /// Creates the command and its options.
  InitCommand() {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Sobrescribe los archivos que ya existan.',
      )
      ..addFlag(
        'pub',
        defaultsTo: true,
        help:
            'Agrega las dependencias y ejecuta flutter gen-l10n '
            '(usa --no-pub para solo crear los archivos).',
      )
      ..addFlag(
        'auth',
        negatable: false,
        help:
            'Agrega autenticación con Firebase (email + Google), como '
            '`flutter_clean_arch auth`.',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Crea la estructura general: core, app, bootstrap, flavors, home, '
      'página no encontrada, l10n y dependencias.';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final runPub = argResults!['pub'] as bool;
    final project = FlutterProject.load(Directory.current.path);

    final generator = await TemplateGenerator.locate();
    final files = generator.render('init', {
      'package': project.package,
      'appTitle': appTitleFromPackage(project.package),
      'todoTag': todoTagFromPackage(project.package),
    });

    // Check every destination before writing anything.
    final conflicts = [
      for (final f in files)
        if (File(project.path(f.relativePath)).existsSync()) f.relativePath,
    ];
    if (conflicts.isNotEmpty && !force) {
      stderr
        ..writeln('Estos archivos ya existen (usa --force para sobrescribir):')
        ..writeln(conflicts.map((c) => '  • $c').join('\n'));
      return 1;
    }

    writeAll(project.root, files);
    stdout.writeln('✓ ${files.length} archivos creados.');

    _deleteFlutterCreateDefaults(project);
    _enableL10nGeneration(project);
    _configureAndroidFlavors(project);

    if (runPub) {
      addDependencies(project, [...initDependencies, ...initDevDependencies]);
      final steps = [
        [
          'flutter',
          ['pub', 'get'],
        ],
        [
          'flutter',
          ['gen-l10n'],
        ],
        [
          'dart',
          ['fix', '--apply', '--code=directives_ordering', 'lib'],
        ],
        [
          'dart',
          ['format', 'lib', 'test'],
        ],
      ];
      for (final step in steps) {
        final code = await runCommand(
          step[0] as String,
          step[1] as List<String>,
          workingDirectory: project.root,
        );
        if (code != 0) {
          stderr.writeln('✗ Falló el paso anterior (código $code).');
          return code;
        }
      }
    }

    if (argResults!['auth'] as bool) {
      final code = await installAuth(project, runPub: runPub);
      if (code != 0) return code;
    }

    stdout
      ..writeln('\n✓ Estructura creada.')
      ..writeln('Siguientes pasos:')
      ..writeln('  flutter_clean_arch feature <nombre>')
      ..writeln(
        '  flutter run --flavor development -t lib/main_development.dart',
      );
    if (!runPub) {
      stdout.writeln(
        '  (sin --pub: agrega las dependencias y ejecuta flutter gen-l10n)',
      );
    }
    return 0;
  }

  /// Adds the development / staging / production flavors to Android, used
  /// by the `--flavor` arguments of `.vscode/launch.json`.
  void _configureAndroidFlavors(FlutterProject project) {
    const gradle = 'android/app/build.gradle.kts';
    const manifest = 'android/app/src/main/AndroidManifest.xml';
    if (!Directory(project.path('android')).existsSync()) {
      stdout.writeln('• Sin carpeta android/: no se configuran flavors.');
      return;
    }

    final appTitle = appTitleFromPackage(project.package);
    final gradleResult = addProductFlavors(
      File(project.path(gradle)),
      appTitle,
    );
    switch (gradleResult) {
      case FlavorResult.updated:
        stdout.writeln('✓ $gradle: flavors development, staging, production.');
      case FlavorResult.alreadyConfigured:
        stdout.writeln('• $gradle ya tenía productFlavors.');
      case FlavorResult.notApplied:
        stderr
          ..writeln(
            '! No se pudo editar $gradle (no existe o no tiene buildTypes). '
            'Agrega esto dentro de android { ... }:',
          )
          ..writeln(productFlavorsBlock(appTitle));
        // Without the flavors, the manifest placeholder would break builds.
        return;
    }

    switch (useFlavorAppName(File(project.path(manifest)))) {
      case FlavorResult.updated:
        stdout.writeln(r'✓ AndroidManifest.xml: android:label="${appName}".');
      case FlavorResult.alreadyConfigured:
        break;
      case FlavorResult.notApplied:
        stderr.writeln(
          r'! No se pudo poner android:label="${appName}" en '
          '$manifest. Hazlo a mano para que cada flavor tenga su nombre.',
        );
    }
  }

  void _deleteFlutterCreateDefaults(FlutterProject project) {
    for (final relative in _flutterCreateDefaults) {
      final path = project.path(relative);
      if (readText(path)?.contains('MyApp') ?? false) {
        deleteFile(path);
        stdout.writeln('✓ Eliminado $relative (plantilla de flutter create).');
      }
    }
  }

  /// Adds `flutter_localizations` (an SDK package, which `flutter pub add`
  /// cannot add reliably on every platform) and sets
  /// `flutter: generate: true`, required by flutter gen-l10n.
  void _enableL10nGeneration(FlutterProject project) {
    final path = project.path('pubspec.yaml');
    final source = readText(path)!;
    final editor = YamlEditor(source);
    final pubspec = loadYaml(source) as YamlMap;
    final deps = pubspec['dependencies'] as YamlMap;
    if (!deps.containsKey('flutter_localizations')) {
      editor.update(
        ['dependencies', 'flutter_localizations'],
        {'sdk': 'flutter'},
      );
    }
    if (pubspec['flutter'] is YamlMap) {
      editor.update(['flutter', 'generate'], true);
    } else {
      editor.update(
        ['flutter'],
        {
          'generate': true,
          'uses-material-design': true,
        },
      );
    }
    writeText(path, editor.toString());
    stdout.writeln(
      '✓ pubspec.yaml: flutter_localizations y flutter.generate = true.',
    );
  }
}
