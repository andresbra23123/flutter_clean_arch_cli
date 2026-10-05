/// `flutter_clean_arch component` and `flutter_clean_arch widget`: add a
/// widget to a page's `components/` folder or to the feature's `widgets/`
/// folder, and export it from that folder's barrel.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';

/// Flutter widget names a generated class must not shadow.
const _flutterWidgets = {
  'AppBar',
  'Button',
  'Card',
  'Center',
  'Column',
  'Container',
  'Divider',
  'Expanded',
  'Icon',
  'Image',
  'ListTile',
  'ListView',
  'Padding',
  'Placeholder',
  'Row',
  'Scaffold',
  'Stack',
  'Text',
};

/// `component <feature> <página> <nombre>`.
class ComponentCommand extends Command<int> {
  /// Creates the command and its options.
  ComponentCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Sobrescribe el archivo si ya existe.',
    );
  }

  @override
  String get name => 'component';

  @override
  String get description =>
      'Agrega un componente a la carpeta components/ de una página y lo '
      'exporta en su barril.';

  @override
  String get invocation =>
      'flutter_clean_arch component <feature> <página> <nombre>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 3) {
      usageException(
        'Indica la feature, la página y el nombre, por ejemplo: '
        'component songs song_detail cover',
      );
    }
    final (project, feature, page) = parseFeatureAndItem(
      rest.sublist(0, 2),
      usageException,
      example: 'component songs song_detail cover',
    );
    final pageDir =
        'lib/features/${feature.snake}/presentation/pages/${page.snake}';
    if (!Directory(project.path(pageDir)).existsSync()) {
      stderr.writeln(
        'La página "${page.snake}" no existe en $pageDir. '
        'Créala con `flutter_clean_arch page ${feature.snake} ${page.snake}`.',
      );
      return 1;
    }
    return generateWidget(
      project,
      feature,
      _parseName(rest[2], usageException),
      folder: '$pageDir/components',
      barrel: 'components.dart',
      description: 'Component used only by the ${page.lowerWords} page.',
      force: argResults!['force'] as bool,
    );
  }
}

/// `widget <feature> <nombre>`.
class WidgetCommand extends Command<int> {
  /// Creates the command and its options.
  WidgetCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Sobrescribe el archivo si ya existe.',
    );
  }

  @override
  String get name => 'widget';

  @override
  String get description =>
      'Agrega un widget compartido a presentation/widgets/ de una feature '
      'y lo exporta en su barril.';

  @override
  String get invocation => 'flutter_clean_arch widget <feature> <nombre>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    final (project, feature, item) = parseFeatureAndItem(
      rest,
      usageException,
      example: 'widget songs song_tile',
    );
    _checkNotFlutterWidget(item, usageException);
    return generateWidget(
      project,
      feature,
      item,
      folder: 'lib/features/${feature.snake}/presentation/widgets',
      barrel: 'widgets.dart',
      description:
          'Widget shared by the pages of the ${feature.lowerWords} '
          'feature.',
      force: argResults!['force'] as bool,
    );
  }
}

FeatureName _parseName(String input, Never Function(String) usageException) {
  final FeatureName name;
  try {
    name = FeatureName.parse(input, allowTaken: true);
  } on FormatException catch (e) {
    usageException(e.message);
  }
  _checkNotFlutterWidget(name, usageException);
  return name;
}

void _checkNotFlutterWidget(
  FeatureName name,
  Never Function(String) usageException,
) {
  if (_flutterWidgets.contains(name.pascal)) {
    usageException(
      '"${name.pascal}" ya es un widget de Flutter. Usa un nombre más '
      'específico, por ejemplo song_${name.snake}.',
    );
  }
}

/// Renders the widget [item] into [folder] and exports it from
/// `[folder]/[barrel]`. Returns 1 if the file exists and [force] is false.
Future<int> generateWidget(
  FlutterProject project,
  FeatureName feature,
  FeatureName item, {
  required String folder,
  required String barrel,
  required String description,
  required bool force,
}) async {
  final relative = '$folder/${item.snake}.dart';
  if (File(project.path(relative)).existsSync() && !force) {
    stderr.writeln('Ya existe $relative (usa --force para sobrescribirlo).');
    return 1;
  }

  final generator = await TemplateGenerator.locate();
  final files = generator.render('component', {
    ...itemVars(project, feature, item),
    'kindDescription': description,
  }, outputPrefix: folder);
  writeAll(project.root, files);
  stdout.writeln('✓ Creado $relative.');

  registerExport(project, '$folder/$barrel', '${item.snake}.dart');

  final code = await runPostSteps(project, [folder]);
  if (code != 0) return code;
  stdout.writeln('\n✓ ${item.pascal} listo.');
  return 0;
}
