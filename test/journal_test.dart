import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  String path(String relative) => p.join(dir.path, relative);
  String? disk(String relative) {
    final f = File(path(relative));
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fca_journal_');
    File(path('kept.txt')).writeAsStringSync('original');
    File(path('gone.txt')).writeAsStringSync('to delete');
    File(path('folder/inside.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('inside');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> changeEverything() async {
    writeText(path('kept.txt'), 'changed');
    writeText(path('new/deep/file.txt'), 'new');
    deleteFile(path('gone.txt'));
    deleteDirectory(path('folder'));
  }

  test('rollback restores modified, created and deleted files', () async {
    final journal = ChangeJournal();
    await journal.run(changeEverything);

    expect(disk('kept.txt'), 'changed');
    expect(disk('new/deep/file.txt'), 'new');
    expect(disk('gone.txt'), isNull);

    expect(journal.rollback(), 4);

    expect(disk('kept.txt'), 'original');
    expect(disk('gone.txt'), 'to delete');
    expect(disk('folder/inside.txt'), 'inside');
    expect(disk('new/deep/file.txt'), isNull);
    // Folders created by the run are removed too.
    expect(Directory(path('new')).existsSync(), isFalse);
  });

  test('dry run writes nothing but later reads see the changes', () async {
    final journal = ChangeJournal(dryRun: true);
    await journal.run(() async {
      await changeEverything();
      expect(readText(path('kept.txt')), 'changed');
      expect(fileExists(path('new/deep/file.txt')), isTrue);
      expect(fileExists(path('gone.txt')), isFalse);
      expect(
        await runCommand('flutter', ['pub', 'get'], workingDirectory: dir.path),
        0,
      );
    });

    expect(disk('kept.txt'), 'original');
    expect(disk('gone.txt'), 'to delete');
    expect(disk('new/deep/file.txt'), isNull);
    expect(journal.skippedCommands, ['flutter pub get']);

    final summary = journal.summary(dir.path);
    expect(summary.created, [p.join('new', 'deep', 'file.txt')]);
    expect(summary.modified, ['kept.txt']);
    expect(
      summary.deleted,
      unorderedEquals(['gone.txt', p.join('folder', 'inside.txt')]),
    );
  });

  test('outside a journal the helpers act on the disk directly', () {
    writeText(path('plain.txt'), 'x');
    expect(disk('plain.txt'), 'x');
    deleteFile(path('plain.txt'));
    expect(disk('plain.txt'), isNull);
  });

  test('keep marks the changes to survive a failure', () async {
    final journal = ChangeJournal();
    await journal.run(() async => journal.keep());
    expect(journal.isKept, isTrue);
  });
}
