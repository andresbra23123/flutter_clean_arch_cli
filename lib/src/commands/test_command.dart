/// `flutter_clean_arch test <feature>`: generates the tests of a feature
/// created with `feature` (use case, repository, BLoC and page).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// `test <feature>`.
class TestCommand extends Command<int> {
  /// Creates the command and its options.
  TestCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Sobrescribe los tests si ya existen.',
    );
  }

  @override
  String get name => 'test';

  @override
  String get description =>
      'Genera los tests de una feature: use case, repositorio, BLoC y '
      'página (bloc_test y mocktail).';

  @override
  String get invocation => 'flutter_clean_arch test <feature>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Indica la feature, por ejemplo: test songs');
    }
    final project = FlutterProject.load(Directory.current.path);
    if (!project.isInitialized) {
      stderr.writeln(
        'No existe lib/core/di/injection_container.dart. '
        'Ejecuta primero `flutter_clean_arch init`.',
      );
      return 1;
    }
    final FeatureName feature;
    try {
      feature = existingFeature(project, rest.single);
    } on FormatException catch (e) {
      usageException(e.message);
    }

    final code = await generateFeatureTests(
      project,
      feature,
      force: argResults!['force'] as bool,
    );
    if (code != 0) return code;

    final postCode = await runPostSteps(project, [
      'test/features/${feature.snake}',
    ]);
    if (postCode != 0) return postCode;
    stdout
      ..writeln('\n✓ Tests de "${feature.snake}" listos.')
      ..writeln(
        '  Ejecútalos con: flutter test test/features/${feature.snake}',
      );
    return 0;
  }
}

/// Renders the tests of [feature] into `test/features/<feature>/`.
///
/// Only works on the structure `feature` generates: returns 1 when the
/// default use case is missing, or when the tests exist and [force] is
/// false.
Future<int> generateFeatureTests(
  FlutterProject project,
  FeatureName feature, {
  required bool force,
}) async {
  final useCase =
      'lib/features/${feature.snake}/domain/usecases/get_${feature.snake}.dart';
  if (!fileExists(project.path(useCase))) {
    stderr.writeln(
      'No existe $useCase. `test` genera los tests de la estructura que crea '
      '`feature` (Get${feature.pascal}UseCaseImpl, ${feature.pascal}Bloc…).',
    );
    return 1;
  }
  final testDir = 'test/features/${feature.snake}';
  if (Directory(project.path(testDir)).existsSync() && !force) {
    stderr.writeln('Ya existe $testDir (usa --force para sobrescribirlo).');
    return 1;
  }

  final generator = await TemplateGenerator.locate();
  final files = generator.render('test_feature', {
    'package': project.package,
    'todoTag': todoTagFromPackage(project.package),
    'name': feature.snake,
    'Name': feature.pascal,
    'nameCamel': feature.camel,
    'nameTitle': feature.title,
    'nameWords': feature.lowerWords,
  }, outputPrefix: 'test/features');
  writeAll(project.root, files);
  stdout.writeln('✓ ${files.length} tests creados en $testDir.');
  return 0;
}
