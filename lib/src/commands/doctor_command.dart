/// `flutter_clean_arch doctor`: checks barrels, markers and feature
/// registrations; `--fix` creates the missing barrels and exports.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/doctor.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/project_config.dart';
import 'package:flutter_clean_arch/src/registry.dart';
import 'package:flutter_clean_arch/src/version.dart';

/// `doctor`: checks barrels, markers and DI registrations.
class DoctorCommand extends Command<int> {
  /// Creates the command and its options.
  DoctorCommand() {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Crea los barriles y exports que falten.',
    );
  }

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Revisa que cada carpeta tenga su barril, que existan los marcadores '
      'y que cada feature esté registrada en el DI.';

  @override
  String get invocation => 'flutter_clean_arch doctor [--fix]';

  @override
  Future<int> run() async {
    final project = FlutterProject.load(Directory.current.path);
    if (!project.isInitialized) {
      stderr.writeln(
        'No existe lib/core/di/injection_container.dart. '
        'Ejecuta primero `flutter_clean_arch init`.',
      );
      return 1;
    }

    final version = await cliVersion();
    final config = readProjectConfig(project.root);
    final last = config?.lastModifiedWith;
    if (version != null && last != null && compareVersions(last, version) < 0) {
      stdout.writeln(
        '• El proyecto se modificó por última vez con la versión $last de la '
        'CLI y tienes la $version. Revisa el CHANGELOG por si quieres aplicar '
        'algo nuevo: $changelogUrl\n',
      );
    }

    var issues = diagnose(project, cliVersion: version);
    if (issues.isEmpty) {
      stdout.writeln('✓ Todo en orden.');
      return 0;
    }

    if (argResults!['fix'] as bool) {
      final fixed = fixIssues(project, issues, cliVersion: version);
      // Keep the fixes even if other problems remain (exit code 1).
      ChangeJournal.current?.keep();
      final done = fixed == 1 ? 'corregido' : 'corregidos';
      stdout.writeln('✓ ${_problems(fixed)} $done.');
      final code = await runPostSteps(project, ['lib']);
      if (code != 0) return code;
      issues = diagnose(project);
      if (issues.isEmpty) {
        stdout.writeln('\n✓ Todo en orden.');
        return 0;
      }
    }

    stderr.writeln('\n${_problems(issues.length)}:');
    for (final kind in DoctorIssueKind.values) {
      final ofKind = issues.where((i) => i.kind == kind).toList();
      if (ofKind.isEmpty) continue;
      stderr.writeln('\n${_titles[kind]}');
      for (final issue in ofKind) {
        stderr.writeln('  • $issue');
      }
    }
    if (issues.any((i) => i.kind.fixable)) {
      stderr.writeln(
        '\nEjecuta `flutter_clean_arch doctor --fix` para '
        'corregir los que se pueden arreglar solos.',
      );
    }
    return 1;
  }
}

const Map<DoctorIssueKind, String> _titles = {
  DoctorIssueKind.missingBarrel: 'Barriles que faltan:',
  DoctorIssueKind.missingExport: 'Exports que faltan:',
  DoctorIssueKind.missingMarker:
      'Marcadores que faltan (restáuralos a mano, ver README):',
  DoctorIssueKind.unregisteredFeature: 'Features sin registrar en el DI:',
  DoctorIssueKind.missingConfig: 'Configuración del proyecto:',
  DoctorIssueKind.newerProject: 'Versión de la CLI:',
};

/// `1 problema`, `3 problemas`.
String _problems(int count) => count == 1 ? '1 problema' : '$count problemas';
