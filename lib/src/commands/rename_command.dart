/// `flutter_clean_arch rename <feature|page|bloc>`: renames a feature, a
/// page or a BLoC with every reference to it.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_clean_arch/src/commands/remove_command.dart';
import 'package:flutter_clean_arch/src/doctor.dart';
import 'package:flutter_clean_arch/src/naming.dart';
import 'package:flutter_clean_arch/src/project.dart';
import 'package:flutter_clean_arch/src/registry.dart';
import 'package:flutter_clean_arch/src/remover.dart';
import 'package:flutter_clean_arch/src/renamer.dart';

/// `rename`, the parent of the three subcommands.
class RenameCommand extends Command<int> {
  /// Registers the subcommands.
  RenameCommand() {
    addSubcommand(_RenameSubcommand(RenameKind.feature));
    addSubcommand(_RenameSubcommand(RenameKind.page));
    addSubcommand(_RenameSubcommand(RenameKind.bloc));
  }

  @override
  String get name => 'rename';

  @override
  String get description =>
      'Renombra una feature, página o BLoC: carpetas, archivos, clases, '
      'exports, DI y rutas.';
}

class _RenameSubcommand extends Command<int> {
  _RenameSubcommand(this.kind) {
    addConfirmationFlags(argParser);
  }

  final RenameKind kind;

  @override
  String get name => kind.name;

  @override
  String get description => switch (kind) {
    RenameKind.feature => 'Renombra una feature.',
    RenameKind.page => 'Renombra una página de una feature.',
    RenameKind.bloc => 'Renombra un BLoC o Cubit de una feature.',
  };

  @override
  String get invocation => kind == RenameKind.feature
      ? 'flutter_clean_arch rename feature <actual> <nuevo>'
      : 'flutter_clean_arch rename ${kind.name} <feature> <actual> <nuevo>';

  @override
  Future<int> run() async {
    final args = argResults!;
    final rest = args.rest;
    final arity = kind == RenameKind.feature ? 2 : 3;
    if (rest.length != arity) {
      usageException('Argumentos incorrectos. Uso: $invocation');
    }
    final project = FlutterProject.load(Directory.current.path);
    final plan = ChangePlan(project);
    final FeatureName feature;
    final FeatureName from;
    final FeatureName to;
    try {
      if (!project.isInitialized) {
        throw const FormatException(
          'No existe lib/core/di/injection_container.dart. '
          'Ejecuta primero `flutter_clean_arch init`.',
        );
      }
      if (kind == RenameKind.feature) {
        feature = existingFeature(project, rest[0]);
        if (feature.snake == 'home') {
          throw const FormatException(
            'La feature home es parte de la estructura base y no se renombra.',
          );
        }
        from = feature;
        to = FeatureName.parse(rest[1]);
      } else {
        feature = existingFeature(project, rest[0]);
        from = FeatureName.parse(rest[1], allowTaken: true);
        to = FeatureName.parse(rest[2], allowTaken: true);
      }
      planRename(plan, kind: kind, feature: feature, from: from, to: to);
    } on FormatException catch (e) {
      usageException(e.message);
    }

    if (!confirmPlan(plan, args)) return (args['dry-run'] as bool) ? 0 : 1;
    plan.apply();
    stdout.writeln('✓ ${plan.descriptions.length} cambios aplicados.');

    final code = await runPostSteps(project, ['lib', 'test']);
    if (code != 0) return code;

    final issues = diagnose(project);
    if (issues.isNotEmpty) {
      stderr.writeln('\n! doctor encontró problemas tras renombrar:');
      for (final issue in issues) {
        stderr.writeln('  • $issue');
      }
    }
    stdout.writeln(
      '\n✓ "${from.snake}" renombrado a "${to.snake}". Revisa los textos '
      'visibles (títulos, l10n) por si quieres ajustarlos.',
    );
    return 0;
  }
}
