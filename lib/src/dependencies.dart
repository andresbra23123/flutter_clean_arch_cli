/// Adds dependencies to a project's `pubspec.yaml` with fixed version
/// ranges.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Writes [dependencies] (`name:^version`, or `dev:name:^version` for
/// dev_dependencies) into the `pubspec.yaml` of [project].
///
/// Edits the file instead of calling `flutter pub add`: on Windows
/// `flutter` is a `.bat`, and `cmd` would drop the `^` of the constraint.
/// Packages the project already declares keep their version. Returns the
/// names of the packages added; run `flutter pub get` afterwards.
List<String> addDependencies(
  FlutterProject project,
  List<String> dependencies,
) {
  final path = project.path('pubspec.yaml');
  final source = readText(path)!;
  final editor = YamlEditor(source);
  final pubspec = loadYaml(source) as YamlMap;
  final added = <String>[];

  for (final spec in dependencies) {
    final dev = spec.startsWith('dev:');
    final parts = (dev ? spec.substring(4) : spec).split(':');
    final (name, version) = (parts[0], parts[1]);
    final section = dev ? 'dev_dependencies' : 'dependencies';
    final current = pubspec[section];
    if (current is YamlMap && current.containsKey(name)) continue;
    if (current is YamlMap) {
      editor.update([section, name], version);
    } else {
      editor.update([section], {name: version});
    }
    added.add(name);
  }

  if (added.isNotEmpty) writeText(path, editor.toString());
  stdout.writeln(
    added.isEmpty
        ? '• pubspec.yaml ya tenía las dependencias.'
        : '✓ pubspec.yaml: ${added.join(', ')}.',
  );
  return added;
}
