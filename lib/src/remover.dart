/// Text operations that undo what the generators insert (exports, DI
/// registrations, routes, repository methods), and [ChangePlan], which
/// collects file edits and deletions so they can be listed, confirmed and
/// applied together.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/journal.dart';
import 'package:flutter_clean_arch/src/project.dart';

/// Removes the line `export '[uri]';`. Returns [source] unchanged if it is
/// not there.
String removeExport(String source, String uri) =>
    removeLines(source, (line) => line.trim() == "export '$uri';");

/// Removes every line for which [test] (on the raw line) is true.
String removeLines(String source, bool Function(String line) test) {
  final eol = _eol(source);
  final lines = _lines(source);
  final kept = lines.where((l) => !test(l)).toList();
  return kept.length == lines.length ? source : kept.join(eol);
}

/// Removes the entry of a `getIt` cascade (`..registerX(...)`) that
/// contains [needle], with every line it spans.
String removeCascadeEntry(String source, String needle) {
  final lines = _lines(source);
  final hit = lines.indexWhere((l) => l.contains(needle));
  if (hit == -1) return source;
  var start = hit;
  while (start > 0 && !lines[start].trimLeft().startsWith('..')) {
    start--;
  }
  if (!lines[start].trimLeft().startsWith('..')) return source;
  return _removeRange(source, start, _blockEnd(lines, start));
}

/// Removes the `GoRoute(...)` that shows [pageClass] and returns the new
/// source and the `AppRoutes` constant it used (`null` if not found).
({String source, String? constant}) removeGoRoute(
  String source,
  String pageClass,
) {
  final lines = _lines(source);
  final hit = lines.indexWhere((l) => l.contains('$pageClass('));
  if (hit == -1) return (source: source, constant: null);
  var start = hit;
  while (start > 0 && !lines[start].trimLeft().startsWith('GoRoute(')) {
    start--;
  }
  if (!lines[start].trimLeft().startsWith('GoRoute(')) {
    return (source: source, constant: null);
  }
  final end = _blockEnd(lines, start);
  final block = lines.sublist(start, end + 1).join('\n');
  final constant = RegExp(r'path:\s*AppRoutes\.(\w+)').firstMatch(block)?[1];
  return (source: _removeRange(source, start, end), constant: constant);
}

/// Removes the `AppRoutes` constants [constant] and `[constant]Name` with
/// their doc comments, and the section header (`// ── Title ──`) if its
/// section is left empty.
String removeRouteConstants(String source, String constant) {
  var out = source;
  for (final name in [constant, '${constant}Name']) {
    final lines = _lines(out);
    final hit = lines.indexWhere(
      (l) => RegExp('static const String $name\\s*=').hasMatch(l),
    );
    if (hit == -1) continue;
    out = _removeRange(out, _docStart(lines, hit), _statementEnd(lines, hit));
  }
  return _removeEmptySections(out);
}

/// Removes the method [method] (with its doc comment and `@override`) from
/// a class body: an abstract signature or a method with a body.
String removeMethod(String source, String method) {
  final lines = _lines(source);
  final hit = lines.indexWhere(
    (l) =>
        RegExp('\\b$method\\(').hasMatch(l) &&
        !l.trimLeft().startsWith('//') &&
        !l.contains('.$method('),
  );
  if (hit == -1) return source;
  final hasBody = _bodyOpens(lines, hit);
  final end = hasBody ? _blockEnd(lines, hit) : _statementEnd(lines, hit);
  return _removeRange(source, _docStart(lines, hit), end);
}

// ── Helpers ─────────────────────────────────────────────────

String _eol(String source) => source.contains('\r\n') ? '\r\n' : '\n';

List<String> _lines(String source) =>
    source.replaceAll('\r\n', '\n').split('\n');

/// Removes lines [start]..[end] (inclusive) plus one surrounding blank line
/// when that would leave two blank lines together.
String _removeRange(String source, int start, int end) {
  final eol = _eol(source);
  final lines = _lines(source);
  var from = start;
  final before = from > 0 && lines[from - 1].trim().isEmpty;
  final after = end + 1 < lines.length && lines[end + 1].trim().isEmpty;
  if (before && after) from--;
  lines.removeRange(from, end + 1);
  return lines.join(eol);
}

/// First line of the doc comments and annotations right above [index].
int _docStart(List<String> lines, int index) {
  var start = index;
  while (start > 0) {
    final previous = lines[start - 1].trimLeft();
    if (previous.startsWith('///') || previous.startsWith('@')) {
      start--;
    } else {
      break;
    }
  }
  return start;
}

int _depthChange(String line) {
  // Ignore what is inside string literals and line comments.
  final code = line
      .replaceAll(RegExp(r"'(\\.|[^'\\])*'"), "''")
      .replaceAll(RegExp(r'"(\\.|[^"\\])*"'), '""')
      .replaceAll(RegExp(r'//.*$'), '');
  var depth = 0;
  for (final char in code.split('')) {
    if ('([{'.contains(char)) depth++;
    if (')]}'.contains(char)) depth--;
  }
  return depth;
}

/// Last line of the bracketed block that starts at [start].
int _blockEnd(List<String> lines, int start) {
  var depth = 0;
  for (var i = start; i < lines.length; i++) {
    depth += _depthChange(lines[i]);
    if (depth <= 0) return i;
  }
  return lines.length - 1;
}

/// Last line of the statement starting at [start] (ends with `;` at depth 0).
int _statementEnd(List<String> lines, int start) {
  var depth = 0;
  for (var i = start; i < lines.length; i++) {
    depth += _depthChange(lines[i]);
    if (depth <= 0 && lines[i].trimRight().endsWith(';')) return i;
  }
  return start;
}

/// Whether the declaration at [start] has a `{ … }` or `=>` body, rather
/// than ending in `;`.
bool _bodyOpens(List<String> lines, int start) {
  var depth = 0;
  for (var i = start; i < lines.length; i++) {
    final line = lines[i].trimRight();
    depth += _depthChange(line);
    if (line.endsWith('{') && depth > 0) return true;
    if (depth <= 0 && line.endsWith(';')) return false;
  }
  return false;
}

final _sectionHeader = RegExp(r'^\s*// ── ');

String _removeEmptySections(String source) {
  final lines = _lines(source);
  for (var i = lines.length - 1; i >= 0; i--) {
    if (!_sectionHeader.hasMatch(lines[i])) continue;
    final next = lines.indexWhere((l) => l.trim().isNotEmpty, i + 1);
    final emptySection =
        next == -1 ||
        _sectionHeader.hasMatch(lines[next]) ||
        lines[next].trim().startsWith('// flutter_clean_arch:') ||
        lines[next].trim() == '}';
    if (emptySection) {
      return _removeEmptySections(_removeRange(source, i, i));
    }
  }
  return source;
}

// ── Plan ────────────────────────────────────────────────────

/// File edits and deletions that can be listed before being applied.
class ChangePlan {
  /// Creates an empty plan for [project].
  ChangePlan(this.project);

  /// Project the paths are relative to.
  final FlutterProject project;

  /// Human-readable list of every change.
  final descriptions = <String>[];

  final _edits = <String, String>{};
  final _deletions = <String>[];

  /// Whether nothing would change.
  bool get isEmpty => descriptions.isEmpty;

  /// Content of [relative] with the edits planned so far, or `null` if the
  /// file does not exist.
  String? read(String relative) {
    if (_edits.containsKey(relative)) return _edits[relative];
    return readText(project.path(relative));
  }

  /// Plans [transform] on [relative]; recorded as [description] only when
  /// it changes the file.
  void edit(
    String relative,
    String description,
    String Function(String source) transform,
  ) {
    final source = read(relative);
    if (source == null) return;
    final result = transform(source);
    if (result == source) return;
    _edits[relative] = result;
    descriptions.add('$relative: $description');
  }

  /// Plans writing [content] to the new file [relative]. Not listed: the
  /// caller describes the operation (e.g. a folder move) once.
  void create(String relative, String content) {
    _edits[relative] = content;
  }

  /// Adds [description] to the list without any file change of its own.
  void describe(String description) => descriptions.add(description);

  /// Plans deleting the file or folder [relative], if it exists. With
  /// [describe] false it is not listed (part of an operation listed once).
  void delete(String relative, {bool describe = true}) {
    final path = project.path(relative);
    if (!FileSystemEntity.isDirectorySync(path) && !File(path).existsSync()) {
      return;
    }
    _deletions.add(relative);
    if (describe) descriptions.add('Eliminar $relative');
  }

  /// Applies every planned change.
  void apply() {
    for (final relative in _deletions) {
      final path = project.path(relative);
      if (FileSystemEntity.isDirectorySync(path)) {
        deleteDirectory(path);
      } else {
        deleteFile(path);
      }
    }
    _edits.forEach((relative, content) {
      writeText(project.path(relative), content);
    });
  }
}
