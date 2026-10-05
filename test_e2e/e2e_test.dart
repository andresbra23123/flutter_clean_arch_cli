// End-to-end test: creates a real Flutter project, runs every generator
// command on it with the CLI of this checkout, and checks that the result
// passes `flutter analyze` and `flutter test`.
//
// Needs Flutter on the PATH and network access (`flutter pub add`). Takes a
// few minutes, so it lives outside test/ and runs on demand:
//
//   dart test test_e2e
@Tags(['e2e'])
@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String app;
  final cli = p.join(Directory.current.path, 'bin', 'flutter_clean_arch.dart');

  /// Runs [executable] in [workingDirectory] and fails the test, showing
  /// its output, if it does not exit with 0.
  Future<String> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    bool expectFailure = false,
  }) async {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory ?? app,
      // `flutter` is a .bat on Windows and needs a shell; `dart` is an .exe
      // and must not use one: cmd would read `<` and `>` in `List<T>` as
      // redirections.
      runInShell: Platform.isWindows && executable == 'flutter',
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    final output = '${result.stdout}\n${result.stderr}';
    if (expectFailure) {
      if (result.exitCode == 0) {
        fail('`$executable ${args.join(' ')}` debía fallar:\n$output');
      }
      return output;
    }
    if (result.exitCode != 0) {
      fail(
        '`$executable ${args.join(' ')}` falló (${result.exitCode}):\n$output',
      );
    }
    return output;
  }

  Future<String> cliRun(List<String> args) =>
      run('dart', ['run', cli, ...args]);

  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('fca_e2e_');
    app = p.join(temp.path, 'demo_app');
    await run('flutter', [
      'create',
      '--no-pub',
      '--platforms',
      'android',
      '--org',
      'com.example',
      'demo_app',
    ], workingDirectory: temp.path);
  });

  tearDownAll(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may keep a lock on build files for a moment; leave it.
    }
  });

  test(
    'every command produces a project that analyzes and tests clean',
    () async {
      File(p.join(app, 'song.json')).writeAsStringSync(
        jsonEncode([
          {
            'id': 7,
            'title': 'Blue Train',
            'rating': 4.5,
            'released_at': '1957-09-15',
            'cover_url': null,
            'album': {'id': 'a1', 'name': 'Blue Train'},
            'artists': [
              {'id': 'ar1', 'name': 'John Coltrane'},
            ],
            'genres': ['jazz'],
          },
        ]),
      );

      // --dry-run changes nothing.
      final dryRun = await cliRun(['init', '--force', '--dry-run']);
      expect(dryRun, contains('Crearía'));
      expect(File(p.join(app, 'lib/bootstrap.dart')).existsSync(), isFalse);
      expect(File(p.join(app, 'lib/main.dart')).existsSync(), isTrue);

      await cliRun(['init', '--force', '--auth']);
      expect(
        File(p.join(app, '.flutter_clean_arch.yaml')).readAsStringSync(),
        allOf(contains('created_with:'), contains('auth: true')),
      );
      expect(
        File(p.join(app, 'pubspec.yaml')).readAsStringSync(),
        contains('go_router: ^'),
      );
      await cliRun(['feature', 'songs', '--tests']);
      await cliRun(['page', 'songs', 'song_detail', '--bloc', '--tests']);
      await cliRun(['component', 'songs', 'song_detail', 'cover']);
      await cliRun(['page', 'songs', 'song_detail', '--bloc', '--force']);
      await cliRun(['widget', 'songs', 'song_tile']);
      await cliRun(['bloc', 'songs', 'player', '--cubit', '--tests']);
      await cliRun([
        'usecase',
        'songs',
        'delete_song',
        '--params',
        'String',
        '--tests',
      ]);
      await cliRun([
        'usecase',
        'songs',
        'search_songs',
        '--returns',
        'List<SongsEntity>',
        '--params',
        'String',
        '--tests',
      ]);
      await cliRun(['model', 'songs', 'song', '--from-json', 'song.json']);
      await cliRun([
        'rename',
        'page',
        'songs',
        'song_detail',
        'track_info',
        '--yes',
      ]);
      await cliRun(['remove', 'bloc', 'songs', 'player', '--yes']);
      await cliRun(['remove', 'usecase', 'songs', 'delete_song', '--yes']);

      // `page --force` kept the component it already had.
      expect(
        File(
          p.join(
            app,
            'lib/features/songs/presentation/pages/track_info/components/components.dart',
          ),
        ).readAsStringSync(),
        contains("export 'cover.dart';"),
      );
      // remove deleted the tests along with the code.
      expect(
        Directory(
          p.join(app, 'test/features/songs/presentation/bloc/player'),
        ).existsSync(),
        isFalse,
      );

      // A command that fails halfway is undone: a file with a syntax error
      // makes `dart format` fail after `widget` wrote its files.
      final widgets = p.join(app, 'lib/features/songs/presentation/widgets');
      final barrel = File(p.join(widgets, 'widgets.dart')).readAsStringSync();
      final broken = File(p.join(widgets, 'broken.dart'))
        ..writeAsStringSync('class Broken {');
      final failed = await run('dart', [
        'run',
        cli,
        'widget',
        'songs',
        'bad_tile',
      ], expectFailure: true);
      expect(failed, contains('se deshicieron'));
      expect(File(p.join(widgets, 'bad_tile.dart')).existsSync(), isFalse);
      expect(
        File(p.join(widgets, 'widgets.dart')).readAsStringSync(),
        barrel,
      );
      broken.deleteSync();

      expect(await cliRun(['doctor']), contains('Todo en orden'));

      final analyze = await run('flutter', ['analyze', '--no-fatal-infos']);
      expect(analyze, isNot(contains(' error ')));
      expect(analyze, isNot(contains('warning ')));

      await run('flutter', ['test']);
    },
  );
}
