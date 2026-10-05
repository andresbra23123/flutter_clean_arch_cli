/// Reads and validates the Flutter project the CLI runs in.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Thrown when the current directory is not a usable Flutter project.
class ProjectException implements Exception {
  /// Creates the exception with the [message] shown to the user.
  const ProjectException(this.message);

  /// Explanation shown to the user, in Spanish.
  final String message;

  @override
  String toString() => message;
}

/// A Flutter project on disk.
class FlutterProject {
  const FlutterProject._(this.root, this.package);

  /// Loads the project at [root] (the folder that contains `pubspec.yaml`).
  ///
  /// Throws a [ProjectException] if there is no pubspec, it has no name or
  /// it does not depend on Flutter.
  factory FlutterProject.load(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw const ProjectException(
        'No se encontró pubspec.yaml. Ejecuta el comando en la raíz de un '
        'proyecto Flutter (créalo con `flutter create <nombre>`).',
      );
    }
    final yaml = loadYaml(pubspec.readAsStringSync());
    if (yaml is! YamlMap || yaml['name'] is! String) {
      throw const ProjectException('pubspec.yaml no tiene un `name:` válido.');
    }
    final deps = yaml['dependencies'];
    if (deps is! YamlMap || !deps.containsKey('flutter')) {
      throw const ProjectException(
        'El proyecto no depende de Flutter (falta `flutter: sdk: flutter` '
        'en dependencies).',
      );
    }
    return FlutterProject._(root, yaml['name'] as String);
  }

  /// Absolute path of the project folder.
  final String root;

  /// Package name from pubspec.yaml, used in `package:` imports.
  final String package;

  /// Absolute path of [relative] inside the project.
  String path(String relative) => p.join(root, relative);

  /// Whether `init` has already been run in this project.
  bool get isInitialized =>
      File(path('lib/core/di/injection_container.dart')).existsSync();
}
