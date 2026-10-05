/// Runs external commands (flutter, dart) and shows their output.
library;

import 'dart:io';

import 'package:flutter_clean_arch/src/journal.dart';
import 'package:path/path.dart' as p;

/// Runs [executable] with [arguments] in [workingDirectory], streaming its
/// output to the console. Returns the exit code.
///
/// Uses a shell on Windows, where `flutter` and `dart` are `.bat` files.
Future<int> runCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final line = '$executable ${arguments.join(' ')}';
  final journal = ChangeJournal.current;
  if (journal != null && journal.dryRun) {
    journal.skippedCommands.add(line);
    return 0;
  }
  if (arguments.isNotEmpty && arguments.first == 'pub') {
    // `pub get` rewrites the lock file: keep it to undo a failed command.
    recordBeforeExternalChange(p.join(workingDirectory, 'pubspec.lock'));
  }
  stdout.writeln('\n\$ $line');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
