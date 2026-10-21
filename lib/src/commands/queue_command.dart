/// `flutter_clean_arch queue`: adds the processing queue (offline outbox
/// in SQLite) and its example features to a project initialized with
/// `init`.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/queue_installer.dart';

/// `queue`.
class QueueCommand extends Command<int> {
  /// Creates the command and its options.
  QueueCommand() {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Reinstala la cola de procesamiento aunque ya exista.',
      )
      ..addFlag(
        'pub',
        defaultsTo: true,
        help:
            'Agrega sqflite, path y sqflite_common_ffi y ejecuta '
            'flutter gen-l10n (usa --no-pub para solo crear los archivos).',
      );
  }

  @override
  String get name => 'queue';

  @override
  String get description =>
      'Agrega una cola de procesamiento offline (SQLite): la base de datos '
      'local, la feature processing_queue, las features de ejemplo '
      'transactions y feedback, y sus tests.';

  @override
  String get invocation => 'flutter_clean_arch queue';

  @override
  Future<int> run() async {
    final project = FlutterProject.load(Directory.current.path);
    if (!project.isInitialized) {
      stderr.writeln(
        'No existe lib/core/di/injection_container.dart. '
        'Ejecuta primero `flutter_clean_arch init` (o `init --queue`).',
      );
      return 1;
    }
    if (Directory(project.path('lib/features/processing_queue')).existsSync() &&
        !(argResults!['force'] as bool)) {
      stderr.writeln(
        'Ya existe lib/features/processing_queue (usa --force para '
        'reinstalarla).',
      );
      return 1;
    }
    return installQueue(project, runPub: argResults!['pub'] as bool);
  }
}
