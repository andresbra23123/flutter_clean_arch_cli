import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late TemplateGenerator generator;
  late Directory dir;
  late FlutterProject project;

  setUpAll(() async => generator = await TemplateGenerator.locate());

  String read(String relative) =>
      File(p.join(dir.path, relative)).readAsStringSync();

  bool exists(String relative) =>
      FileSystemEntity.typeSync(p.join(dir.path, relative)) !=
      FileSystemEntityType.notFound;

  /// Renders `feature <name>` and registers it like the command does.
  void addFeature(String name) {
    final f = FeatureName.parse(name);
    writeAll(
      dir.path,
      generator.render('feature', {
        'package': 'demo_app',
        'todoTag': 'demo-app',
        'name': f.snake,
        'Name': f.pascal,
        'nameCamel': f.camel,
        'nameTitle': f.title,
        'nameWords': f.lowerWords,
      }, outputPrefix: 'lib/features'),
    );
    inject(
      project,
      'lib/core/di/injection_container.dart',
      Markers.featureImports,
      featureBarrelImport(project, f),
    );
    inject(
      project,
      'lib/core/di/injection_container.dart',
      Markers.featureInit,
      '  init${f.pascal}Dependencies();',
    );
    inject(
      project,
      'lib/core/router/app_routes.dart',
      Markers.routes,
      routeConstants(
        constName: f.camel,
        path: '/${f.snake}',
        routeName: f.snake,
        title: f.title,
        words: f.lowerWords,
      ),
    );
    inject(
      project,
      'lib/core/router/app_router.dart',
      Markers.routes,
      goRoute(constName: f.camel, pageClass: '${f.pascal}Page'),
    );
  }

  /// Renders `bloc <feature> <name>` (only the files).
  void addBloc(String feature, String name) {
    final f = FeatureName.parse(feature);
    final item = FeatureName.parse(name, allowTaken: true);
    final root = 'lib/features/${f.snake}/presentation/bloc';
    writeAll(
      dir.path,
      generator.render(
        'bloc',
        itemVars(project, f, item),
        outputPrefix: root,
      ),
    );
    addExport(
      File(p.join(dir.path, '$root/bloc.dart')),
      '${item.snake}/${item.snake}.dart',
    );
    insertBeforeMarker(
      File(p.join(dir.path, 'lib/features/$feature/${feature}_injection.dart')),
      Markers.blocs,
      '    ..registerFactory(${item.pascal}Bloc.new)',
    );
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fca_rename_');
    writeAll(dir.path, [
      const RenderedFile(
        'pubspec.yaml',
        'name: demo_app\ndependencies:\n  flutter:\n    sdk: flutter\n',
      ),
      ...generator.render('init', {
        'package': 'demo_app',
        'todoTag': 'demo-app',
        'appTitle': 'Demo App',
      }),
    ]);
    project = FlutterProject.load(dir.path);
    addFeature('songs');
    addFeature('song');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void rename(RenameKind kind, String feature, String from, String to) {
    final plan = ChangePlan(project);
    planRename(
      plan,
      kind: kind,
      feature: FeatureName.parse(feature, allowTaken: true),
      from: FeatureName.parse(from, allowTaken: true),
      to: FeatureName.parse(to, allowTaken: true),
    );
    plan.apply();
  }

  test('rename feature moves it and updates DI and routes', () {
    rename(RenameKind.feature, 'songs', 'songs', 'tracks');

    expect(exists('lib/features/songs'), isFalse);
    expect(read('lib/features/tracks/tracks.dart'), contains('library;'));
    expect(
      read('lib/features/tracks/presentation/bloc/tracks/tracks_bloc.dart'),
      contains('class TracksBloc'),
    );
    expect(
      read('lib/core/di/injection_container.dart'),
      allOf(
        contains("import 'package:demo_app/features/tracks/tracks.dart';"),
        contains('initTracksDependencies();'),
        isNot(contains('initSongsDependencies')),
      ),
    );
    expect(
      read('lib/core/router/app_routes.dart'),
      allOf(
        contains("static const String tracks = '/tracks';"),
        contains("static const String tracksName = 'tracks';"),
      ),
    );
    expect(
      read('lib/core/router/app_router.dart'),
      allOf(contains('AppRoutes.tracks,'), contains('const TracksPage()')),
    );
    // The `song` feature shares a prefix but must not change.
    expect(
      read('lib/features/song/presentation/bloc/song/song_bloc.dart'),
      contains('class SongBloc'),
    );
    expect(
      read('lib/core/di/injection_container.dart'),
      contains('initSongDependencies();'),
    );
  });

  test('rename bloc with a one-word name picks each case correctly', () {
    addBloc('songs', 'player');

    rename(RenameKind.bloc, 'songs', 'player', 'audio_player');

    const root = 'lib/features/songs/presentation/bloc/audio_player';
    expect(
      read('$root/audio_player_bloc.dart'),
      allOf(
        contains("part 'audio_player_event.dart';"),
        contains('class AudioPlayerBloc extends Bloc<AudioPlayerEvent'),
        isNot(contains('audio player_')),
      ),
    );
    expect(
      read('$root/audio_player.dart'),
      contains("export 'audio_player_bloc.dart';"),
    );
    expect(
      read('lib/features/songs/presentation/bloc/bloc.dart'),
      contains("export 'audio_player/audio_player.dart';"),
    );
    expect(
      read('lib/features/songs/songs_injection.dart'),
      contains('..registerFactory(AudioPlayerBloc.new)'),
    );
  });

  test('rename page keeps the names declared outside its folder', () {
    final f = FeatureName.parse('songs');
    final item = FeatureName.parse('detail');
    const pages = 'lib/features/songs/presentation/pages';
    writeAll(dir.path, [
      ...generator.render(
        'page',
        itemVars(project, f, item),
        outputPrefix: pages,
      ),
      ...generator.render(
        'page_bloc',
        itemVars(project, f, item),
        outputPrefix: pages,
      ),
    ]);
    addBloc('songs', 'detail');

    rename(RenameKind.page, 'songs', 'detail', 'info');

    final page = read('$pages/info/info_page.dart');
    expect(page, contains('class InfoPage'));
    // The BLoC was not renamed, so the page still uses DetailBloc.
    expect(page, contains('getIt<DetailBloc>()'));
    expect(exists('lib/features/songs/presentation/bloc/detail'), isTrue);
  });

  test('refuses to overwrite an existing folder', () {
    expect(
      () => rename(RenameKind.feature, 'songs', 'songs', 'song'),
      throwsFormatException,
    );
  });
}
