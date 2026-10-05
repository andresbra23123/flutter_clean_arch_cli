/// Records every file the CLI touches while running a command, so the
/// command can be undone when it fails ([ChangeJournal.rollback]) or only
/// simulated (`--dry-run`).
///
/// Code writes and reads project files through [writeText], [readText],
/// [fileExists], [deleteFile] and [deleteDirectory]. Outside a journal
/// (e.g. in unit tests) they act on the disk directly.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

final Object _zoneKey = Object();

/// The file changes of one command run.
class ChangeJournal {
  /// Creates a journal. With [dryRun], nothing is written to disk: changes
  /// stay in memory, visible to later reads of the same run.
  ChangeJournal({this.dryRun = false});

  /// Whether this run only simulates its changes.
  final bool dryRun;

  /// Original content of every touched file (`null`: it did not exist).
  final _original = <String, String?>{};

  /// Folders that did not exist before this run.
  final _createdDirs = <String>{};

  /// Simulated content of the touched files (`null`: deleted). Dry run only.
  final _pending = <String, String?>{};

  /// External commands that were not run because of [dryRun].
  final skippedCommands = <String>[];

  /// Set by [keep]: the changes stay even if the command fails.
  bool _kept = false;

  /// Journal of the running command, if any.
  static ChangeJournal? get current => Zone.current[_zoneKey] as ChangeJournal?;

  /// Runs [body] with this journal as [current].
  Future<T> run<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: this});

  /// Keeps the changes made so far even if the command then fails (for
  /// commands that report problems after successfully changing files, like
  /// `doctor --fix`).
  void keep() => _kept = true;

  /// Whether [keep] was called.
  bool get isKept => _kept;

  /// Number of files touched.
  int get length => _original.length;

  void _remember(String path) {
    if (_original.containsKey(path)) return;
    final file = File(path);
    _original[path] = file.existsSync() ? file.readAsStringSync() : null;
  }

  void _rememberDirs(String path) {
    var dir = p.dirname(path);
    final missing = <String>[];
    while (!Directory(dir).existsSync() && p.dirname(dir) != dir) {
      missing.add(dir);
      dir = p.dirname(dir);
    }
    _createdDirs.addAll(missing);
  }

  String? _read(String path) {
    if (dryRun && _pending.containsKey(path)) return _pending[path];
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  void _write(String path, String content) {
    _remember(path);
    if (dryRun) {
      _pending[path] = content;
      return;
    }
    _rememberDirs(path);
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  void _delete(String path) {
    if (_read(path) == null) return;
    _remember(path);
    if (dryRun) {
      _pending[path] = null;
    } else {
      File(path).deleteSync();
    }
  }

  /// Restores every touched file to its original state and removes the
  /// folders this run created. Returns how many files were restored.
  int rollback() {
    if (dryRun) return 0;
    var restored = 0;
    _original.forEach((path, content) {
      final file = File(path);
      if (content == null) {
        if (file.existsSync()) file.deleteSync();
      } else {
        file
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      }
      restored++;
    });
    final dirs = _createdDirs.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final dir in dirs) {
      final d = Directory(dir);
      if (d.existsSync() && d.listSync().isEmpty) d.deleteSync();
    }
    return restored;
  }

  /// Files a dry run would create, modify and delete, relative to [root].
  ({List<String> created, List<String> modified, List<String> deleted}) summary(
    String root,
  ) {
    final created = <String>[];
    final modified = <String>[];
    final deleted = <String>[];
    _original.forEach((path, original) {
      final now = dryRun ? _pending[path] : _read(path);
      final relative = p.relative(path, from: root);
      if (original == null && now != null) {
        created.add(relative);
      } else if (original != null && now == null) {
        deleted.add(relative);
      } else if (original != now) {
        modified.add(relative);
      }
    });
    return (
      created: created..sort(),
      modified: modified..sort(),
      deleted: deleted..sort(),
    );
  }
}

/// Content of the text file at [path], or `null` if it does not exist.
/// Inside a dry run, sees what the run already wrote.
String? readText(String path) {
  final journal = ChangeJournal.current;
  if (journal != null) return journal._read(path);
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Whether the file at [path] exists (or was created by this dry run).
bool fileExists(String path) => readText(path) != null;

/// Writes [content] to [path], creating its folders.
void writeText(String path, String content) {
  final journal = ChangeJournal.current;
  if (journal != null) {
    journal._write(path, content);
  } else {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
}

/// Deletes the file at [path] if it exists.
void deleteFile(String path) {
  final journal = ChangeJournal.current;
  if (journal != null) {
    journal._delete(path);
  } else if (File(path).existsSync()) {
    File(path).deleteSync();
  }
}

/// Deletes the folder at [path] and everything in it.
void deleteDirectory(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return;
  final journal = ChangeJournal.current;
  if (journal == null) {
    dir.deleteSync(recursive: true);
    return;
  }
  for (final file in dir.listSync(recursive: true).whereType<File>()) {
    journal._delete(file.path);
  }
  if (!journal.dryRun && dir.existsSync()) dir.deleteSync(recursive: true);
}

/// Records [path] (e.g. `pubspec.lock`) before an external command changes
/// it, so [ChangeJournal.rollback] can restore it.
void recordBeforeExternalChange(String path) =>
    ChangeJournal.current?._remember(path);
