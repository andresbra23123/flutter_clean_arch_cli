/// The `flutter_clean_arch` command runner: every command, the global
/// `--version` flag, and the safety net around each command (undo on
/// failure, `--dry-run`, uncommitted-changes check).
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/commands/auth_command.dart';
import 'package:flutter_clean_arch/src/commands/bloc_command.dart';
import 'package:flutter_clean_arch/src/commands/doctor_command.dart';
import 'package:flutter_clean_arch/src/commands/feature_command.dart';
import 'package:flutter_clean_arch/src/commands/init_command.dart';
import 'package:flutter_clean_arch/src/commands/model_command.dart';
import 'package:flutter_clean_arch/src/commands/page_command.dart';
import 'package:flutter_clean_arch/src/commands/remove_command.dart';
import 'package:flutter_clean_arch/src/commands/rename_command.dart';
import 'package:flutter_clean_arch/src/commands/test_command.dart';
import 'package:flutter_clean_arch/src/commands/usecase_command.dart';
import 'package:flutter_clean_arch/src/commands/widget_command.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/project_config.dart';
import 'package:flutter_clean_arch/src/version.dart';
import 'package:path/path.dart' as p;

/// Runs the CLI.
class CliRunner extends CommandRunner<int> {
  /// Registers every command and the global options.
  CliRunner()
    : super(
        'flutter_clean_arch',
        'Genera la estructura Clean Architecture de un proyecto Flutter.',
      ) {
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Muestra la versión instalada.',
    );
    addCommand(InitCommand());
    addCommand(FeatureCommand());
    addCommand(AuthCommand());
    addCommand(PageCommand());
    addCommand(BlocCommand());
    addCommand(UsecaseCommand());
    addCommand(ComponentCommand());
    addCommand(WidgetCommand());
    addCommand(ModelCommand());
    addCommand(TestCommand());
    addCommand(RemoveCommand());
    addCommand(RenameCommand());
    addCommand(DoctorCommand());
    _addSafetyFlags();
  }

  /// Gives every command that changes files `--dry-run` and
  /// `--allow-dirty` (those that already have them keep their own).
  void _addSafetyFlags() {
    void visit(Command<int> command) {
      if (command.subcommands.isNotEmpty) {
        command.subcommands.values.toSet().forEach(visit);
        return;
      }
      // The built-in `help` command changes nothing.
      if (command.name == 'help') return;
      final options = command.argParser.options;
      if (!options.containsKey('dry-run')) {
        command.argParser.addFlag(
          'dry-run',
          negatable: false,
          help:
              'Muestra qué archivos crearía, modificaría o eliminaría y qué '
              'comandos ejecutaría, sin cambiar nada.',
        );
      }
      if (command.name != 'doctor' && !options.containsKey('allow-dirty')) {
        command.argParser.addFlag(
          'allow-dirty',
          negatable: false,
          help: 'Continúa aunque el repositorio git tenga cambios sin commit.',
        );
      }
    }

    commands.values.toSet().forEach(visit);
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] as bool) {
      stdout.writeln(
        'flutter_clean_arch ${await cliVersion() ?? 'desconocida'}',
      );
      return 0;
    }

    final (path, args) = _leaf(topLevelResults);
    if (args == null || !args.options.contains('dry-run')) {
      return super.runCommand(topLevelResults);
    }

    final dryRun = args['dry-run'] as bool;
    if (!dryRun) _checkUncommittedChanges(path, args);
    if (dryRun) {
      stdout.writeln('(--dry-run) Simulación: no se escribirá nada.\n');
    }

    final journal = ChangeJournal(dryRun: dryRun);
    final int? code;
    try {
      code = await journal.run(() => super.runCommand(topLevelResults));
    } catch (_) {
      _undo(journal);
      rethrow;
    }
    if ((code ?? 0) != 0) {
      _undo(journal);
    } else if (dryRun) {
      _printDryRun(journal);
    } else if (journal.length > 0) {
      await _updateProjectConfig(path, args);
    }
    return code;
  }

  /// Names and results of the command that actually runs (`remove page`).
  (List<String>, ArgResults?) _leaf(ArgResults top) {
    final path = <String>[];
    var results = top;
    while (results.command != null) {
      results = results.command!;
      path.add(results.name!);
    }
    return (path, path.isEmpty ? null : results);
  }

  /// Stops risky commands (`remove`, `rename`, `auth`, any `--force`) when
  /// the git repository has uncommitted changes, so they can be undone
  /// with git. `--allow-dirty` skips the check.
  void _checkUncommittedChanges(List<String> path, ArgResults args) {
    final risky =
        const {'remove', 'rename', 'auth'}.contains(path.first) ||
        (args.options.contains('force') && args['force'] == true);
    if (!risky || (args['allow-dirty'] as bool? ?? false)) return;

    final ProcessResult status;
    try {
      status = Process.runSync('git', [
        'status',
        '--porcelain',
      ], workingDirectory: Directory.current.path);
    } on ProcessException {
      return; // git is not installed.
    }
    final command = path.join(' ');
    if (status.exitCode != 0) {
      stdout.writeln(
        '• El proyecto no está en un repositorio git: si `$command` no hace '
        'lo esperado, no podrás deshacerlo con git.\n',
      );
      return;
    }
    final changes = (status.stdout as String)
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .length;
    if (changes == 0) return;
    final files = changes == 1 ? '1 archivo' : '$changes archivos';
    throw ProjectException(
      'Hay $files con cambios sin commit. `$command` modifica '
      'archivos del proyecto: haz commit (o stash) antes para poder '
      'deshacerlo con git, revisa qué haría con --dry-run, o usa '
      '--allow-dirty para continuar igualmente.',
    );
  }

  void _undo(ChangeJournal journal) {
    if (journal.dryRun || journal.isKept) return;
    final restored = journal.rollback();
    if (restored > 0) {
      stderr.writeln(
        '\n✗ El comando no terminó: se deshicieron sus cambios en '
        '$restored archivos, el proyecto quedó como estaba.',
      );
    }
  }

  void _printDryRun(ChangeJournal journal) {
    final summary = journal.summary(Directory.current.path);
    final sections = {
      'Crearía': summary.created,
      'Modificaría': summary.modified,
      'Eliminaría': summary.deleted,
      'Ejecutaría': journal.skippedCommands,
    };
    if (sections.values.every((l) => l.isEmpty)) return;
    stdout.writeln('\n(--dry-run) No se cambió nada. Esto es lo que haría:');
    sections.forEach((title, items) {
      if (items.isEmpty) return;
      stdout.writeln('\n$title (${items.length}):');
      for (final item in items) {
        stdout.writeln('  • ${item.replaceAll(r'\', '/')}');
      }
    });
  }

  /// Records in `.flutter_clean_arch.yaml` the CLI version that changed
  /// the project.
  Future<void> _updateProjectConfig(List<String> path, ArgResults args) async {
    final root = Directory.current.path;
    if (!File(p.join(root, 'pubspec.yaml')).existsSync()) return;
    final version = await cliVersion();
    if (version == null) return;
    final installsAuth =
        path.first == 'auth' || (path.first == 'init' && args['auth'] == true);
    final current = readProjectConfig(root);
    writeProjectConfig(
      root,
      ProjectConfig(
        createdWith:
            current?.createdWith ?? (path.first == 'init' ? version : null),
        lastModifiedWith: version,
        auth: (current?.auth ?? false) || installsAuth,
      ),
    );
  }
}
