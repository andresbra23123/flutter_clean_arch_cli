/// Plans renaming a feature, a page or a BLoC: its folder, files, classes,
/// exports, DI registrations and routes.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/remover.dart';
import 'package:path/path.dart' as p;

/// What `rename` renames.
enum RenameKind {
  /// `lib/features/<name>/`.
  feature,

  /// `lib/features/<feature>/presentation/pages/<name>/`.
  page,

  /// `lib/features/<feature>/presentation/bloc/<name>/`.
  bloc,
}

/// Fills [plan] with the changes that rename [from] to [to].
///
/// [feature] is the feature that contains the page or BLoC (for
/// [RenameKind.feature] it is [from] itself). Throws a [FormatException]
/// with a readable message when the rename is not possible.
void planRename(
  ChangePlan plan, {
  required RenameKind kind,
  required FeatureName feature,
  required FeatureName from,
  required FeatureName to,
}) {
  final project = plan.project;
  if (from.snake == to.snake) {
    throw const FormatException('El nombre nuevo es igual al actual.');
  }

  // Folders that move: the item and its mirror under test/.
  final String libDir;
  final String parentBarrel;
  switch (kind) {
    case RenameKind.feature:
      libDir = 'lib/features/${from.snake}';
      parentBarrel = '';
    case RenameKind.page:
      libDir = 'lib/features/${feature.snake}/presentation/pages/${from.snake}';
      parentBarrel = p.posix.join(p.posix.dirname(libDir), 'pages.dart');
    case RenameKind.bloc:
      libDir = 'lib/features/${feature.snake}/presentation/bloc/${from.snake}';
      parentBarrel = p.posix.join(p.posix.dirname(libDir), 'bloc.dart');
  }
  if (!Directory(project.path(libDir)).existsSync()) {
    throw FormatException('No existe $libDir.');
  }
  final newLibDir = p.posix.join(p.posix.dirname(libDir), to.snake);
  if (Directory(project.path(newLibDir)).existsSync()) {
    throw FormatException('Ya existe $newLibDir.');
  }
  final dirs = {
    libDir: newLibDir,
    'test${libDir.substring(3)}': 'test${newLibDir.substring(3)}',
  }..removeWhere((old, _) => !Directory(project.path(old)).existsSync());

  // Identifiers declared inside the moved folders, and AppRoutes constants
  // that belong to them, mapped to their new names.
  final identifiers = <String, String>{};
  for (final dir in dirs.keys) {
    for (final file in _dartFiles(project, dir)) {
      for (final id in _declarations(file.readAsStringSync())) {
        final renamed = _renameIdentifier(id, from, to);
        if (renamed != id) identifiers[id] = renamed;
      }
    }
  }
  final routes = _routeConstants(project, kind, feature, from, to);

  // Identifiers declared outside the moved folders keep their names even
  // if they contain the old name (e.g. the BLoC a renamed page uses).
  final declaredOutside = <String>{
    for (final folder in ['lib', 'test'])
      if (Directory(project.path(folder)).existsSync())
        for (final file in _dartFiles(project, folder))
          if (!dirs.keys.any(
            (d) => p.isWithin(project.path(d), file.path),
          ))
            ..._declarations(file.readAsStringSync()),
  }..removeAll(identifiers.keys);

  // 1. Move the folders, renaming files and contents.
  final package = project.package;
  dirs.forEach((oldDir, newDir) {
    final files = _dartFiles(project, oldDir).toList()
      ..addAll(
        Directory(project.path(oldDir))
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !f.path.endsWith('.dart')),
      );
    for (final file in files) {
      final relative = p.posix.joinAll(
        p.split(p.relative(file.path, from: project.path(oldDir))),
      );
      final renamedPath = relative
          .split('/')
          .map((s) => s.replaceAll(from.snake, to.snake))
          .join('/');
      var content = _replaceForms(
        file.readAsStringSync(),
        from,
        to,
        package,
        kind == RenameKind.feature ? null : feature,
        keep: declaredOutside,
      );
      content = _replaceRoutes(content, routes);
      plan.create('$newDir/$renamedPath', content);
    }
    plan
      ..delete(oldDir, describe: false)
      ..describe('Mover $oldDir → $newDir (${files.length} archivos)');
  });

  // 2. Update every other Dart file of lib/ and test/.
  for (final folder in ['lib', 'test']) {
    final root = Directory(project.path(folder));
    if (!root.existsSync()) continue;
    for (final file in _dartFiles(project, folder)) {
      final relative = p.posix.joinAll(
        p.split(p.relative(file.path, from: project.root)),
      );
      if (dirs.keys.any((d) => relative.startsWith('$d/'))) continue;
      plan.edit(relative, 'actualizar referencias', (source) {
        var out = source;
        if (kind == RenameKind.feature) {
          final oldRoot = 'package:$package/features/${from.snake}/';
          final newRoot = 'package:$package/features/${to.snake}/';
          out = replaceAllOnce(out, {
            '$oldRoot${from.snake}.dart': '$newRoot${to.snake}.dart',
            oldRoot: newRoot,
          });
        }
        if (relative == parentBarrel) {
          out = out.replaceAll(
            "'${from.snake}/${from.snake}.dart'",
            "'${to.snake}/${to.snake}.dart'",
          );
        }
        out = replaceAllOnce(out, identifiers, wholeWords: true);
        out = _replaceRoutes(out, routes);
        if (relative == 'lib/core/router/app_routes.dart') {
          out = _renameRouteDefinitions(out, kind, feature, from, to, routes);
        }
        return out;
      });
    }
  }
}

Iterable<File> _dartFiles(FlutterProject project, String relative) =>
    Directory(project.path(relative))
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

final _typeDeclaration = RegExp(
  r'^\s*(?:abstract |sealed |final |base |interface )*'
  r'(?:class|enum|mixin|extension|typedef)\s+(\w+)',
  multiLine: true,
);

final _functionDeclaration = RegExp(
  r'^(?:Future<[\w<>?, ]+>|void|[A-Z]\w*)\s+(\w+)\s*\(',
  multiLine: true,
);

Iterable<String> _declarations(String source) => [
  ..._typeDeclaration.allMatches(source).map((m) => m[1]!),
  ..._functionDeclaration.allMatches(source).map((m) => m[1]!),
];

String _renameIdentifier(String id, FeatureName from, FeatureName to) {
  var out = id.replaceAll(from.pascal, to.pascal);
  if (out.startsWith(from.camel)) {
    out = to.camel + out.substring(from.camel.length);
  }
  return out;
}

/// Replaces every case of [from] with [to] inside a moved file, keeping
/// intact the package name, the feature path (for pages and BLoCs:
/// [keepFeature]) and the identifiers in [keep].
String _replaceForms(
  String source,
  FeatureName from,
  FeatureName to,
  String package,
  FeatureName? keepFeature, {
  Set<String> keep = const {},
}) {
  final masks = <String>[];
  String mask(Match m) {
    masks.add(m[0]!);
    return '\u0000${masks.length - 1}\u0000';
  }

  var out = source.replaceAllMapped('package:$package/', mask);
  if (keepFeature != null) {
    out = out.replaceAllMapped('features/${keepFeature.snake}/', mask);
  }
  final kept = keep.where((id) => out.contains(id)).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (kept.isNotEmpty) {
    out = out.replaceAllMapped(
      RegExp('\\b(${kept.map(RegExp.escape).join('|')})\\b'),
      mask,
    );
  }

  out = _replaceNameForms(out, from, to);
  return out.replaceAllMapped(
    RegExp('\u0000(\\d+)\u0000'),
    (m) => masks[int.parse(m[1]!)],
  );
}

/// Replaces the five cases of [from] with those of [to] in one pass.
///
/// A one-word name has cases that look the same (`player` is snake, camel
/// and plain words; `Player` is Pascal and title). The surrounding text
/// picks one: paths and file names get snake, identifiers get camel or
/// Pascal, and comments and strings get the words.
String _replaceNameForms(String source, FeatureName from, FeatureName to) {
  const snake = 0;
  const pascal = 1;
  const camel = 2;
  const title = 3;
  const words = 4;
  final oldForms = [
    from.snake,
    from.pascal,
    from.camel,
    from.title,
    from.lowerWords,
  ];
  final newForms = [to.snake, to.pascal, to.camel, to.title, to.lowerWords];
  final kindsOf = <String, List<int>>{};
  for (var i = 0; i < oldForms.length; i++) {
    kindsOf.putIfAbsent(oldForms[i], () => []).add(i);
  }
  final keys = kindsOf.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(keys.map(RegExp.escape).join('|'));
  final identifierChar = RegExp(r'[A-Za-z0-9$]');

  return source.replaceAllMapped(pattern, (m) {
    final kinds = kindsOf[m[0]!]!;
    if (kinds.length == 1) return newForms[kinds.single];

    final text = m.input;
    final before = m.start > 0 ? text[m.start - 1] : '';
    final after = m.end < text.length ? text[m.end] : '';
    final lineStart = text.lastIndexOf('\n', m.start) + 1;
    final linePrefix = text.substring(lineStart, m.start);
    final inComment = linePrefix.contains('//');
    final inString =
        "'".allMatches(linePrefix).length.isOdd ||
        '"'.allMatches(linePrefix).length.isOdd;
    final glued =
        identifierChar.hasMatch(before) || identifierChar.hasMatch(after);

    int pick() {
      if (kinds.contains(snake)) {
        if ('_/.\'"'.contains(before) && before.isNotEmpty ||
            '_/.\'"'.contains(after) && after.isNotEmpty) {
          return snake;
        }
        if (glued || (!inComment && !inString)) return camel;
        return words;
      }
      // Pascal and title.
      if (glued || (!inComment && !inString)) return pascal;
      return title;
    }

    final kind = pick();
    return newForms[kinds.contains(kind) ? kind : kinds.first];
  });
}

/// `AppRoutes` constants (and their `…Name`) renamed by this operation.
Map<String, String> _routeConstants(
  FlutterProject project,
  RenameKind kind,
  FeatureName feature,
  FeatureName from,
  FeatureName to,
) {
  final file = File(project.path('lib/core/router/app_routes.dart'));
  if (!file.existsSync() || kind == RenameKind.bloc) return const {};
  final names = RegExp(
    r'static const String (\w+)\s*=',
  ).allMatches(file.readAsStringSync()).map((m) => m[1]!);
  final map = <String, String>{};
  for (final name in names) {
    if (kind == RenameKind.feature &&
        (name == from.camel ||
            name == '${from.camel}Name' ||
            RegExp('^${from.camel}[A-Z]').hasMatch(name))) {
      map[name] = to.camel + name.substring(from.camel.length);
    }
    final pageConst = '${feature.camel}${from.pascal}';
    if (kind == RenameKind.page &&
        (name == pageConst || name == '${pageConst}Name')) {
      map[name] =
          '${feature.camel}${to.pascal}${name.substring(pageConst.length)}';
    }
  }
  return map;
}

String _replaceRoutes(String source, Map<String, String> routes) =>
    replaceAllOnce(source, {
      for (final MapEntry(:key, :value) in routes.entries)
        'AppRoutes.$key': 'AppRoutes.$value',
    }, wholeWords: true);

/// Replaces every key of [replacements] with its value in a single pass,
/// so a new value that contains an old key is never replaced again
/// (`player` → `audio_player` must not become `audio_audio_player`).
///
/// Longer keys win over shorter ones. With [wholeWords], a key only
/// matches when it is not followed or preceded by an identifier character.
String replaceAllOnce(
  String source,
  Map<String, String> replacements, {
  bool wholeWords = false,
}) {
  final keys = replacements.keys.where((k) => k.isNotEmpty).toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (keys.isEmpty) return source;
  final alternatives = keys.map(RegExp.escape).join('|');
  final pattern = wholeWords
      ? RegExp('(?<![A-Za-z0-9_\$])($alternatives)(?![A-Za-z0-9_\$])')
      : RegExp(alternatives);
  return source.replaceAllMapped(
    pattern,
    (m) => replacements[wholeWords ? m[1]! : m[0]!]!,
  );
}

/// Renames the constants, paths, route names and section header in
/// `app_routes.dart`.
String _renameRouteDefinitions(
  String source,
  RenameKind kind,
  FeatureName feature,
  FeatureName from,
  FeatureName to,
  Map<String, String> routes,
) {
  final out = replaceAllOnce(source, {
    for (final MapEntry(:key, :value) in routes.entries)
      'static const String $key': 'static const String $value',
  }, wholeWords: true);

  final (
    oldPath,
    newPath,
    oldName,
    newName,
    oldTitle,
    newTitle,
  ) = kind == RenameKind.feature
      ? (
          '/${from.snake}',
          '/${to.snake}',
          from.snake,
          to.snake,
          from.title,
          to.title,
        )
      : (
          '/${feature.snake}/${from.snake}',
          '/${feature.snake}/${to.snake}',
          '${feature.snake}_${from.snake}',
          '${feature.snake}_${to.snake}',
          '${feature.title} · ${from.title}',
          '${feature.title} · ${to.title}',
        );
  return replaceAllOnce(out, {
        "'$oldPath'": "'$newPath'",
        "'$oldPath/": "'$newPath/",
        "'$oldName'": "'$newName'",
        "'${oldName}_": "'${newName}_",
      })
      .split('\n')
      .map(
        (l) => l.trimLeft().startsWith('// ── ')
            ? l.replaceAll(oldTitle, newTitle)
            : l,
      )
      .join('\n');
}
