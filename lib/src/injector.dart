/// Inserts code into existing files at marker comments.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/journal.dart';

/// Outcome of [insertBeforeMarker].
enum InjectResult {
  /// The snippet was added.
  inserted,

  /// The snippet was already in the file; nothing changed.
  alreadyPresent,

  /// The file or the marker does not exist; nothing changed.
  markerNotFound,
}

/// Inserts [snippet] on the lines right before the line whose trimmed
/// content is [marker].
///
/// Idempotent: if the file already contains [snippet], it is not added
/// again. Keeps the file's line endings (LF or CRLF).
InjectResult insertBeforeMarker(File file, String marker, String snippet) {
  final source = readText(file.path);
  if (source == null) return InjectResult.markerNotFound;
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final normalized = source.replaceAll('\r\n', '\n');
  final cleanSnippet = snippet.replaceAll('\r\n', '\n').trimRight();

  if (normalized.contains(cleanSnippet)) return InjectResult.alreadyPresent;

  final lines = normalized.split('\n');
  final index = lines.indexWhere((l) => l.trim() == marker.trim());
  if (index == -1) return InjectResult.markerNotFound;

  lines.insertAll(index, cleanSnippet.split('\n'));
  writeText(file.path, lines.join('\n').replaceAll('\n', eol));
  return InjectResult.inserted;
}

/// URIs exported by the barrel [file] (empty if it does not exist).
List<String> readExports(File file) {
  final source = readText(file.path);
  if (source == null) return const [];
  return RegExp(
    r'''^export\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(source).map((m) => m[1]!).toList();
}

/// Adds `export '[uri]';` to the barrel [file], keeping its exports sorted.
///
/// Creates the barrel (doc comment, `library;` and the export) if it does
/// not exist, so it never returns [InjectResult.markerNotFound].
/// Idempotent and keeps the file's line endings.
InjectResult addExport(File file, String uri) {
  final line = "export '$uri';";
  final source = readText(file.path);
  if (source == null) {
    writeText(
      file.path,
      '/// Barrel file: exports the public files of this folder.\n'
      'library;\n\n$line\n',
    );
    return InjectResult.inserted;
  }
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  if (lines.any((l) => l.trim() == line)) return InjectResult.alreadyPresent;

  final exportIndexes = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].startsWith('export ')) i,
  ];
  if (exportIndexes.isEmpty) {
    // No exports yet: add them after the last non-empty line.
    final last = lines.lastIndexWhere((l) => l.trim().isNotEmpty);
    lines.insertAll(last + 1, ['', line]);
  } else {
    // Insert before the first export that sorts after it.
    final before = exportIndexes.firstWhere(
      (i) => lines[i].compareTo(line) > 0,
      orElse: () => exportIndexes.last + 1,
    );
    lines.insert(before, line);
  }
  var out = lines.join('\n');
  if (!out.endsWith('\n')) out += '\n';
  writeText(file.path, out.replaceAll('\n', eol));
  return InjectResult.inserted;
}

/// Adds [imports] after the last import of [source] (sorted later by
/// `dart fix`). Skips the ones already present.
String addImports(String source, List<String> imports) {
  final missing = imports.where((i) => !source.contains(i)).toList();
  if (missing.isEmpty) return source;
  final lines = source.split('\n');
  final last = lines.lastIndexWhere((l) => l.startsWith('import '));
  lines.insertAll(last + 1, missing);
  return lines.join('\n');
}

/// Adds the missing [imports] to the Dart file [file], keeping its line
/// endings. Does nothing if the file does not exist.
void ensureImports(File file, List<String> imports) {
  final source = readText(file.path);
  if (source == null) return;
  final eol = source.contains('\r\n') ? '\r\n' : '\n';
  final normalized = source.replaceAll('\r\n', '\n');
  final result = addImports(normalized, imports);
  if (result != normalized) writeText(file.path, result.replaceAll('\n', eol));
}
