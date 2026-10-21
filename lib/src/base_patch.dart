/// Idempotent edits of the base files created by `init`, shared by the
/// installers that add a module to a project (`auth`, `queue`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/project.dart';

/// An idempotent edit of a base file.
class BasePatch {
  /// Creates the edit of [relative], described by [description].
  const BasePatch(
    this.relative,
    this.description, {
    required this.done,
    required this.edit,
    required this.manual,
  });

  /// Path of the file, relative to the project.
  final String relative;

  /// What the edit adds, shown in the output.
  final String description;

  /// Whether the file already has the change.
  final bool Function(String source) done;

  /// The edited source, or `null` if the expected code was not found.
  final String? Function(String source) edit;

  /// What to change by hand when [edit] cannot.
  final String manual;

  /// Applies the edit to [project], keeping the file's line endings.
  void apply(FlutterProject project) {
    final path = project.path(relative);
    final source = readText(path);
    if (source == null) {
      stderr.writeln('! No existe $relative. Cambio a mano: $manual');
      return;
    }
    if (done(source)) {
      stdout.writeln('• $relative ya tenía: $description.');
      return;
    }
    final eol = source.contains('\r\n') ? '\r\n' : '\n';
    final result = edit(source.replaceAll('\r\n', '\n'));
    if (result == null) {
      stderr
        ..writeln('! No se pudo editar $relative automáticamente.')
        ..writeln('  Cambio a mano: $manual');
      return;
    }
    writeText(path, result.replaceAll('\n', eol));
    stdout.writeln('✓ $relative: $description.');
  }
}

/// Index of the `)` that closes the `(` at [open].
int closingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Adds the keys of [arbs] (`app_en.arb` / `app_es.arb`) to the project's
/// ARB files, keeping the existing keys and their order. [module] names
/// the keys in the output, e.g. `auth`.
void mergeArb(FlutterProject project, List<RenderedFile> arbs, String module) {
  for (final arb in arbs) {
    final relative = 'lib/core/l10n/arb/${arb.relativePath}';
    final source = readText(project.path(relative));
    if (source == null) {
      stderr.writeln(
        '! No existe $relative: agrega a mano las claves de $module.',
      );
      continue;
    }
    final existing = jsonDecode(source) as Map<String, dynamic>;
    final additions = jsonDecode(arb.content) as Map<String, dynamic>;
    var added = 0;
    additions.forEach((key, value) {
      if (existing.containsKey(key)) return;
      existing[key] = value;
      if (!key.startsWith('@')) added++;
    });
    if (added == 0) {
      stdout.writeln('• $relative ya tenía las claves de $module.');
      continue;
    }
    writeText(
      project.path(relative),
      '${const JsonEncoder.withIndent('    ').convert(existing)}\n',
    );
    stdout.writeln('✓ $relative: $added claves de $module.');
  }
}
