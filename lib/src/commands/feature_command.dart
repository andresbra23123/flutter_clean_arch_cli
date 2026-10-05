/// `flutter_clean_arch feature <name>`: creates a feature with its three
/// layers and registers it in the DI and the router.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/commands/test_command.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// `feature <nombre>`: creates a feature with its three layers.
class FeatureCommand extends Command<int> {
  /// Creates the command and its options.
  FeatureCommand() {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Regenera la feature aunque ya exista.',
      )
      ..addFlag(
        'route',
        defaultsTo: true,
        help:
            'Registra la página en AppRoutes y AppRouter '
            '(usa --no-route para features sin pantalla propia).',
      )
      ..addFlag(
        'tests',
        negatable: false,
        help: 'Genera también sus tests (como `test <feature>`).',
      );
  }

  @override
  String get name => 'feature';

  @override
  String get description =>
      'Crea una feature (data, domain, presentation y barriles) y la '
      'registra en el DI y el router.';

  @override
  String get invocation => 'flutter_clean_arch feature <nombre>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Indica un solo nombre, por ejemplo: feature songs');
    }
    final FeatureName feature;
    try {
      feature = FeatureName.parse(rest.single);
    } on FormatException catch (e) {
      usageException(e.message);
    }
    final force = argResults!['force'] as bool;
    final withRoute = argResults!['route'] as bool;
    final project = FlutterProject.load(Directory.current.path);

    if (!project.isInitialized) {
      stderr.writeln(
        'No existe lib/core/di/injection_container.dart. '
        'Ejecuta primero `flutter_clean_arch init`.',
      );
      return 1;
    }
    final featureDir = Directory(project.path('lib/features/${feature.snake}'));
    if (featureDir.existsSync() && !force) {
      stderr.writeln(
        'La feature "${feature.snake}" ya existe en ${featureDir.path} '
        '(usa --force para regenerarla).',
      );
      return 1;
    }

    final generator = await TemplateGenerator.locate();
    final files = generator.render(
      'feature',
      {
        'package': project.package,
        'todoTag': todoTagFromPackage(project.package),
        'name': feature.snake,
        'Name': feature.pascal,
        'nameCamel': feature.camel,
        'nameTitle': feature.title,
        'nameWords': feature.lowerWords,
      },
      outputPrefix: 'lib/features',
    );
    writeAll(project.root, files);
    stdout.writeln(
      '✓ ${files.length} archivos creados en lib/features/${feature.snake}.',
    );

    final barrelImport = featureBarrelImport(project, feature);

    inject(
      project,
      'lib/core/di/injection_container.dart',
      Markers.featureImports,
      barrelImport,
    );
    inject(
      project,
      'lib/core/di/injection_container.dart',
      Markers.featureInit,
      '  init${feature.pascal}Dependencies();',
    );

    if (withRoute) {
      inject(
        project,
        'lib/core/router/app_routes.dart',
        Markers.routes,
        routeConstants(
          constName: feature.camel,
          path: '/${feature.snake}',
          routeName: feature.snake,
          title: feature.title,
          words: feature.lowerWords,
        ),
      );
      inject(
        project,
        'lib/core/router/app_router.dart',
        Markers.featureImports,
        barrelImport,
      );
      inject(
        project,
        'lib/core/router/app_router.dart',
        Markers.routes,
        goRoute(constName: feature.camel, pageClass: '${feature.pascal}Page'),
      );
    }

    final withTests = argResults!['tests'] as bool;
    if (withTests) {
      final testCode = await generateFeatureTests(
        project,
        feature,
        force: force,
      );
      if (testCode != 0) return testCode;
    }

    final code = await runPostSteps(project, [
      'lib/features/${feature.snake}',
      'lib/core',
      if (withTests) 'test/features/${feature.snake}',
    ]);
    if (code != 0) return code;

    stdout.writeln('\n✓ Feature "${feature.snake}" lista.');
    if (withRoute) {
      stdout.writeln(
        '  Navega con: context.goNamed(AppRoutes.${feature.camel}Name)',
      );
    }
    return 0;
  }
}
