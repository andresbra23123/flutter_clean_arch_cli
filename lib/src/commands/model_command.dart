/// `flutter_clean_arch model <feature> <name> --from-json <file>`: generates
/// entities and models from a sample JSON.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/json_model.dart';
import 'package:flutter_clean_arch/src/registry.dart';
import 'package:path/path.dart' as p;

/// `model <feature> <nombre> --from-json <archivo>`.
class ModelCommand extends Command<int> {
  /// Creates the command and its options.
  ModelCommand() {
    argParser
      ..addOption(
        'from-json',
        valueHelp: 'archivo',
        help:
            'Obligatoria. Archivo con un JSON de ejemplo (objeto o lista '
            'de objetos).',
      )
      ..addFlag(
        'nullable',
        negatable: false,
        help: 'Hace nullable todos los campos.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Sobrescribe las entidades y modelos que ya existan.',
      );
  }

  @override
  String get name => 'model';

  @override
  String get description =>
      'Genera la entidad y el modelo (fromJson/toJson) de una feature a '
      'partir de un JSON de ejemplo, incluidos los objetos anidados.';

  @override
  String get invocation =>
      'flutter_clean_arch model <feature> <nombre> --from-json <archivo>';

  @override
  Future<int> run() async {
    // Read the mandatory option first: its error must win over the project.
    final jsonPath = argResults!['from-json'] as String?;
    if (jsonPath == null) {
      usageException(
        'Falta la opción obligatoria --from-json <archivo>, por ejemplo: '
        'model songs song --from-json song.json',
      );
    }
    final (project, feature, item) = parseFeatureAndItem(
      argResults!.rest,
      usageException,
      example: 'model songs song --from-json song.json',
    );
    final force = argResults!['force'] as bool;

    final featureRoot = 'lib/features/${feature.snake}';
    if (!Directory(project.path('$featureRoot/domain')).existsSync() ||
        !Directory(project.path('$featureRoot/data')).existsSync()) {
      stderr.writeln(
        'La feature "${feature.snake}" no tiene capas domain/ y data/.',
      );
      return 1;
    }

    final jsonFile = File(jsonPath);
    if (!jsonFile.existsSync()) {
      stderr.writeln('No existe el archivo $jsonPath.');
      return 1;
    }
    final List<RenderedFile> files;
    try {
      files = modelsFromJson(
        json: jsonDecode(jsonFile.readAsStringSync()),
        package: project.package,
        feature: feature,
        name: item,
        source: p.basename(jsonPath),
        nullable: argResults!['nullable'] as bool,
      );
    } on FormatException catch (e) {
      stderr.writeln('El JSON de $jsonPath no es válido: ${e.message}');
      return 1;
    }

    final existing = [
      for (final f in files)
        if (File(project.path(f.relativePath)).existsSync()) f.relativePath,
    ];
    if (existing.isNotEmpty && !force) {
      stderr
        ..writeln('Estos archivos ya existen (usa --force para sobrescribir):')
        ..writeln(existing.map((e) => '  • $e').join('\n'));
      return 1;
    }

    writeAll(project.root, files);
    for (final f in files) {
      stdout.writeln('✓ Creado ${f.relativePath}.');
      final folder = p.posix.dirname(f.relativePath);
      registerExport(
        project,
        '$folder/${p.posix.basename(folder)}.dart',
        p.posix.basename(f.relativePath),
      );
    }
    if (item.snake == feature.snake && existing.isNotEmpty) {
      stdout.writeln(
        '\n• Se reemplazaron ${item.pascal}Entity y ${item.pascal}Model: '
        'revisa el código de la feature que usaba sus campos anteriores '
        '(por ejemplo `id` en ${item.pascal}Widget y en los tests).',
      );
    }

    final code = await runPostSteps(project, [featureRoot]);
    if (code != 0) return code;
    stdout.writeln(
      '\n✓ ${files.length ~/ 2} entidades y modelos listos en la feature '
      '"${feature.snake}".',
    );
    return 0;
  }
}
