/// `flutter_clean_arch auth`: adds Firebase authentication (email +
/// Google) to a project initialized with `init`.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/auth_installer.dart';
import 'package:flutter_clean_arch/src/project.dart';

/// `auth`.
class AuthCommand extends Command<int> {
  /// Creates the command and its options.
  AuthCommand() {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Reinstala la feature auth aunque ya exista.',
      )
      ..addFlag(
        'pub',
        defaultsTo: true,
        help:
            'Agrega firebase_core, firebase_auth y google_sign_in y ejecuta '
            'flutter gen-l10n (usa --no-pub para solo crear los archivos).',
      );
  }

  @override
  String get name => 'auth';

  @override
  String get description =>
      'Agrega autenticación con Firebase (email + Google): la feature auth, '
      'sus tests, la redirección del router y las opciones por flavor.';

  @override
  String get invocation => 'flutter_clean_arch auth';

  @override
  Future<int> run() async {
    final project = FlutterProject.load(Directory.current.path);
    if (!project.isInitialized) {
      stderr.writeln(
        'No existe lib/core/di/injection_container.dart. '
        'Ejecuta primero `flutter_clean_arch init` (o `init --auth`).',
      );
      return 1;
    }
    if (Directory(project.path('lib/features/auth')).existsSync() &&
        !(argResults!['force'] as bool)) {
      stderr.writeln(
        'Ya existe lib/features/auth (usa --force para reinstalarla).',
      );
      return 1;
    }
    return installAuth(project, runPub: argResults!['pub'] as bool);
  }
}
