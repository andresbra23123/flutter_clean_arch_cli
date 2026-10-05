/// `flutter_clean_arch page <feature> <name>`: adds a page, in its own
/// folder with a `components/` folder, to an existing feature and
/// registers its route.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/commands/bloc_command.dart';
import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/injector.dart';
import 'package:flutter_clean_arch/src/item_tests.dart';
import 'package:flutter_clean_arch/src/registry.dart';
import 'package:path/path.dart' as p;

/// `page <feature> <nombre>`: adds a page to a feature.
class PageCommand extends Command<int> {
  /// Creates the command and its options.
  PageCommand() {
    argParser
      ..addFlag(
        'route',
        defaultsTo: true,
        help:
            'Registra la página en AppRoutes y AppRouter '
            '(usa --no-route para páginas que no son una ruta).',
      )
      ..addFlag(
        'bloc',
        negatable: false,
        help: 'Crea también un BLoC con el mismo nombre y lo usa en la página.',
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
  String get name => 'page';

  @override
  String get description =>
      'Agrega una página (con su carpeta components/) a una feature y '
      'registra su ruta.';

  @override
  String get invocation => 'flutter_clean_arch page <feature> <nombre>';

  @override
  Future<int> run() async {
    final (project, feature, item) = parseFeatureAndItem(
      argResults!.rest,
      usageException,
      example: 'page songs song_detail',
    );
    final force = argResults!['force'] as bool;
    final withRoute = argResults!['route'] as bool;
    final withBloc = argResults!['bloc'] as bool;

    final pagesRoot = 'lib/features/${feature.snake}/presentation/pages';
    final dir = Directory(project.path('$pagesRoot/${item.snake}'));
    if (dir.existsSync() && !force) {
      stderr.writeln(
        'Ya existe $pagesRoot/${item.snake} (usa --force para sobrescribirla).',
      );
      return 1;
    }

    // `AppRoutes.songsSongDetail`, path `/songs/song_detail`.
    final constName = '${feature.camel}${item.pascal}';
    final appRoutes = File(project.path('lib/core/router/app_routes.dart'));
    if (withRoute &&
        appRoutes.existsSync() &&
        appRoutes.readAsStringSync().contains(
          'static const String $constName ',
        ) &&
        !force) {
      stderr.writeln(
        'AppRoutes.$constName ya existe (usa --no-route o elige otro '
        'nombre).',
      );
      return 1;
    }

    if (withBloc) {
      final code = await generateBloc(
        project,
        feature,
        item,
        cubit: false,
        force: force,
      );
      if (code != 0) return code;
    }

    final generator = await TemplateGenerator.locate();
    final vars = itemVars(project, feature, item);
    final files = {
      for (final f in generator.render('page', vars, outputPrefix: pagesRoot))
        f.relativePath: f,
      // The BLoC version of the page replaces the plain one.
      if (withBloc)
        for (final f in generator.render(
          'page_bloc',
          vars,
          outputPrefix: pagesRoot,
        ))
          f.relativePath: f,
    }.values.toList();
    // With --force, keep the exports of the components the page already had:
    // the template's components.dart has none.
    final componentsBarrel = File(
      project.path('$pagesRoot/${item.snake}/components/components.dart'),
    );
    final keptComponents = readExports(componentsBarrel);

    writeAll(project.root, files);
    stdout.writeln(
      '✓ ${files.length} archivos creados en $pagesRoot/${item.snake}.',
    );
    for (final uri in keptComponents) {
      if (File(p.join(componentsBarrel.parent.path, uri)).existsSync()) {
        addExport(componentsBarrel, uri);
      }
    }

    registerExport(
      project,
      '$pagesRoot/pages.dart',
      '${item.snake}/${item.snake}.dart',
    );

    if (withRoute) {
      inject(
        project,
        'lib/core/router/app_routes.dart',
        Markers.routes,
        routeConstants(
          constName: constName,
          path: '/${feature.snake}/${item.snake}',
          routeName: '${feature.snake}_${item.snake}',
          title: '${feature.title} · ${item.title}',
          words: item.lowerWords,
        ),
      );
      inject(
        project,
        'lib/core/router/app_router.dart',
        Markers.featureImports,
        featureBarrelImport(project, feature),
      );
      inject(
        project,
        'lib/core/router/app_router.dart',
        Markers.routes,
        goRoute(constName: constName, pageClass: '${item.pascal}Page'),
      );
    }

    final withTests = argResults!['tests'] as bool;
    if (withTests) {
      final tests = [
        ...await writeItemTests(
          project,
          feature,
          item,
          withBloc ? ItemTestKind.pageWithBloc : ItemTestKind.page,
        ),
        if (withBloc)
          ...await writeItemTests(project, feature, item, ItemTestKind.bloc),
      ];
      stdout.writeln('✓ ${tests.length} tests creados.');
    }

    final code = await runPostSteps(project, [
      'lib/features/${feature.snake}',
      if (withRoute) 'lib/core/router',
      if (withTests) 'test/features/${feature.snake}',
    ]);
    if (code != 0) return code;

    stdout.writeln(
      '\n✓ Página "${item.snake}" lista en la feature "${feature.snake}".',
    );
    if (withRoute) {
      stdout.writeln(
        '  Navega con: context.goNamed(AppRoutes.${constName}Name)',
      );
    }
    return 0;
  }
}
