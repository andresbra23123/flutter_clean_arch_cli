/// `flutter_clean_arch usecase <feature> <name>`: adds a use case to an
/// existing feature, its method to the repository and its DI registration.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/injector.dart';
import 'package:flutter_clean_arch/src/item_tests.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// `usecase <feature> <nombre>`: adds a use case to a feature.
class UsecaseCommand extends Command<int> {
  /// Creates the command and its options.
  UsecaseCommand() {
    argParser
      ..addOption(
        'returns',
        defaultsTo: 'Unit',
        help: 'Tipo que devuelve en caso de éxito (p. ej. "List<SongEntity>").',
      )
      ..addOption(
        'params',
        defaultsTo: 'NoParams',
        help: 'Tipo de los parámetros (p. ej. "String").',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Sobrescribe el archivo si ya existe.',
      )
      ..addFlag(
        'tests',
        negatable: false,
        help: 'Genera también sus tests en test/features/<feature>/.',
      );
  }

  @override
  String get name => 'usecase';

  @override
  String get description =>
      'Agrega un use case a una feature, su método al repositorio '
      '(Inter e Impl) y lo registra en el DI.';

  @override
  String get invocation => 'flutter_clean_arch usecase <feature> <nombre>';

  @override
  Future<int> run() async {
    final (project, feature, item) = parseFeatureAndItem(
      argResults!.rest,
      usageException,
      example: 'usecase songs delete_song',
    );
    final returns = (argResults!['returns'] as String).trim();
    final params = (argResults!['params'] as String).trim();
    final force = argResults!['force'] as bool;

    final featureRoot = 'lib/features/${feature.snake}';
    if (!Directory(project.path('$featureRoot/domain')).existsSync()) {
      stderr.writeln(
        'La feature "${feature.snake}" no tiene capa domain/ '
        '(los use cases van en domain/usecases).',
      );
      return 1;
    }
    final usecasesRoot = '$featureRoot/domain/usecases';
    final file = File(project.path('$usecasesRoot/${item.snake}.dart'));
    if (file.existsSync() && !force) {
      stderr.writeln(
        'Ya existe $usecasesRoot/${item.snake}.dart (usa --force para sobrescribirlo).',
      );
      return 1;
    }

    final noParams = params == 'NoParams';
    final generator = await TemplateGenerator.locate();
    final files = generator.render('usecase', {
      ...itemVars(project, feature, item),
      'returns': returns,
      'params': params,
      'callArgs': noParams ? '' : 'params',
      // dartz only when a type uses it (Unit, Option…); FutureEither
      // already comes from core/type_defs.
      'dartzImport': _usesDartz('$returns $params')
          ? "import 'package:dartz/dartz.dart';\n"
          : '',
    }, outputPrefix: usecasesRoot);
    writeAll(project.root, files);
    stdout.writeln('✓ Creado $usecasesRoot/${item.snake}.dart.');

    registerExport(
      project,
      '$usecasesRoot/usecases.dart',
      '${item.snake}.dart',
    );

    final signature =
        'FutureEither<$returns> ${item.camel}'
        '(${noParams ? '' : '$params params'})';
    // Features created by older versions may not import type_defs yet.
    final typeDefs =
        "import 'package:${project.package}/core/type_defs/type_defs.dart';";
    for (final repo in [
      '$featureRoot/domain/repositories/${feature.snake}_repository_inter.dart',
      '$featureRoot/data/repositories/${feature.snake}_repository_impl.dart',
    ]) {
      ensureImports(File(project.path(repo)), [typeDefs]);
    }
    inject(
      project,
      '$featureRoot/domain/repositories/${feature.snake}_repository_inter.dart',
      Markers.repositoryMethods,
      '\n  /// Runs "${item.lowerWords}".\n  $signature;',
    );
    inject(
      project,
      '$featureRoot/data/repositories/${feature.snake}_repository_impl.dart',
      Markers.repositoryMethods,
      '''

  @override
  $signature async {
    // TODO(${todoTagFromPackage(project.package)}): Implement ${item.lowerWords}.
    throw UnimplementedError();
  }''',
    );
    inject(
      project,
      '$featureRoot/${feature.snake}_injection.dart',
      Markers.usecases,
      '    ..registerLazySingleton(\n'
          '      () => ${item.pascal}UseCaseImpl(repository: getIt()),\n'
          '    )',
    );

    final withTests = argResults!['tests'] as bool;
    if (withTests) {
      final test = writeUsecaseTest(
        project,
        feature,
        item,
        returns: returns,
        params: params,
      );
      stdout.writeln('✓ Creado $test.');
    }

    final code = await runPostSteps(project, [
      featureRoot,
      if (withTests) 'test/features/${feature.snake}',
    ]);
    if (code != 0) return code;

    stdout.writeln(
      '\n✓ Use case "${item.snake}" listo en la feature "${feature.snake}".',
    );
    return 0;
  }
}

/// Whether [types] use something from dartz (`Unit`, `Option`, `Either`,
/// `IList`…), so the use case file must import it.
bool _usesDartz(String types) =>
    RegExp(r'\b(Unit|Option|Either|IList|IMap|ISet|Tuple\d)\b').hasMatch(types);
