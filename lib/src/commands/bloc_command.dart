/// `flutter_clean_arch bloc <feature> <name>`: adds a BLoC (or a Cubit) in
/// its own folder to an existing feature and registers it in the DI.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/item_tests.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// `bloc <feature> <nombre>`: adds a BLoC or Cubit to a feature.
class BlocCommand extends Command<int> {
  /// Creates the command and its options.
  BlocCommand() {
    argParser
      ..addFlag(
        'cubit',
        negatable: false,
        help: 'Crea un Cubit en lugar de un BLoC.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Sobrescribe la carpeta si ya existe.',
      )
      ..addFlag(
        'tests',
        negatable: false,
        help: 'Genera también sus tests en test/features/<feature>/.',
      );
  }

  @override
  String get name => 'bloc';

  @override
  String get description =>
      'Agrega un BLoC (o un Cubit con --cubit) en su propia carpeta a una '
      'feature y lo registra en el DI.';

  @override
  String get invocation => 'flutter_clean_arch bloc <feature> <nombre>';

  @override
  Future<int> run() async {
    final (project, feature, item) = parseFeatureAndItem(
      argResults!.rest,
      usageException,
      example: 'bloc songs player',
    );
    final cubit = argResults!['cubit'] as bool;

    final code = await generateBloc(
      project,
      feature,
      item,
      cubit: cubit,
      force: argResults!['force'] as bool,
    );
    if (code != 0) return code;

    final withTests = argResults!['tests'] as bool;
    if (withTests) {
      await writeItemTests(
        project,
        feature,
        item,
        cubit ? ItemTestKind.cubit : ItemTestKind.bloc,
      );
      stdout.writeln('✓ Test creado.');
    }

    final postCode = await runPostSteps(project, [
      'lib/features/${feature.snake}',
      if (withTests) 'test/features/${feature.snake}',
    ]);
    if (postCode != 0) return postCode;

    stdout.writeln(
      '\n✓ ${cubit ? 'Cubit' : 'BLoC'} "${item.snake}" listo en la feature '
      '"${feature.snake}".',
    );
    return 0;
  }
}

/// Renders the BLoC (or Cubit) [item] into [feature], exports it from
/// `bloc/bloc.dart` and registers it in `<feature>_injection.dart`.
///
/// Returns 1 if the folder already exists and [force] is false.
Future<int> generateBloc(
  FlutterProject project,
  FeatureName feature,
  FeatureName item, {
  required bool cubit,
  required bool force,
}) async {
  final blocRoot = 'lib/features/${feature.snake}/presentation/bloc';
  final dir = Directory(project.path('$blocRoot/${item.snake}'));
  if (dir.existsSync() && !force) {
    stderr.writeln(
      'Ya existe $blocRoot/${item.snake} (usa --force para sobrescribirla).',
    );
    return 1;
  }

  final generator = await TemplateGenerator.locate();
  final files = generator.render(
    cubit ? 'cubit' : 'bloc',
    itemVars(project, feature, item),
    outputPrefix: blocRoot,
  );
  writeAll(project.root, files);
  stdout.writeln(
    '✓ ${files.length} archivos creados en $blocRoot/${item.snake}.',
  );

  registerExport(
    project,
    '$blocRoot/bloc.dart',
    '${item.snake}/${item.snake}.dart',
  );
  inject(
    project,
    'lib/features/${feature.snake}/${feature.snake}_injection.dart',
    Markers.blocs,
    '    ..registerFactory(${item.pascal}${cubit ? 'Cubit' : 'Bloc'}.new)',
  );
  return 0;
}
