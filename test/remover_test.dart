import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:test/test.dart';

void main() {
  test('removeExport removes only that export', () {
    const barrel = "library;\n\nexport 'a.dart';\nexport 'b.dart';\n";

    expect(removeExport(barrel, 'a.dart'), "library;\n\nexport 'b.dart';\n");
    expect(removeExport(barrel, 'c.dart'), barrel);
  });

  test('removeCascadeEntry removes one-line and multi-line entries', () {
    const source = '''
void initSongsDependencies() {
  getIt
    ..registerFactory(() => SongsBloc(getSongs: getIt()))
    ..registerFactory(PlayerBloc.new)
    // flutter_clean_arch:blocs
    ..registerLazySingleton(
      () => DeleteSongUseCaseImpl(repository: getIt()),
    )
    // flutter_clean_arch:usecases
    ..registerLazySingleton<SongsRepositoryInter>(SongsRepositoryImpl.new);
}
''';

    final out = removeCascadeEntry(
      removeCascadeEntry(source, 'PlayerBloc.new'),
      'DeleteSongUseCaseImpl(',
    );

    expect(out, isNot(contains('PlayerBloc')));
    expect(out, isNot(contains('DeleteSong')));
    expect(out, contains('SongsBloc(getSongs'));
    expect(out, contains('..registerLazySingleton<SongsRepositoryInter>'));
  });

  test('removeGoRoute returns the AppRoutes constant it used', () {
    const source = '''
    routes: [
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => routerAnimation(
          page: const HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.songsDetail,
        name: AppRoutes.songsDetailName,
        pageBuilder: (context, state) => routerAnimation(
          page: const DetailPage(),
        ),
      ),
      // flutter_clean_arch:routes
    ],
''';

    final result = removeGoRoute(source, 'DetailPage');

    expect(result.constant, 'songsDetail');
    expect(result.source, isNot(contains('DetailPage')));
    expect(result.source, contains('HomePage'));
    expect(result.source, contains('// flutter_clean_arch:routes'));
  });

  test('removeRouteConstants removes constants, docs and empty header', () {
    const source = '''
abstract final class AppRoutes {
  // ── Home ──────────────────────────────────────────────────

  /// Path of the home page.
  static const String home = '/home';

  // ── Songs · Detail ────────────────────────────────────────

  /// Path of the detail page.
  static const String songsDetail = '/songs/detail';

  /// Name of the detail route.
  static const String songsDetailName = 'songs_detail';

  // flutter_clean_arch:routes
}
''';

    final out = removeRouteConstants(source, 'songsDetail');

    expect(out, isNot(contains('songsDetail')));
    expect(out, isNot(contains('Songs · Detail')));
    expect(out, isNot(contains('detail page')));
    expect(out, contains("static const String home = '/home';"));
    expect(out, contains('// ── Home'));
  });

  test('removeMethod removes signatures and implementations', () {
    const inter = '''
abstract interface class SongsRepositoryInter {
  /// Returns the songs.
  Future<Either<Failure, SongsEntity>> getSongs();

  /// Runs "search songs".
  Future<Either<Failure, List<SongsEntity>>> searchSongs(
    String params,
  );
  // flutter_clean_arch:repository-methods
}
''';
    const impl = '''
class SongsRepositoryImpl implements SongsRepositoryInter {
  @override
  Future<Either<Failure, SongsEntity>> getSongs() async {
    final remote = await remoteDataSource.getSongs();
    return Right(remote);
  }

  @override
  Future<Either<Failure, List<SongsEntity>>> searchSongs(String params) async {
    // TODO(demo-app): Implement search songs.
    throw UnimplementedError();
  }
  // flutter_clean_arch:repository-methods
}
''';

    final newInter = removeMethod(inter, 'searchSongs');
    final newImpl = removeMethod(impl, 'searchSongs');

    expect(newInter, isNot(contains('searchSongs')));
    expect(newInter, isNot(contains('search songs')));
    expect(newInter, contains('getSongs();'));
    expect(newImpl, isNot(contains('searchSongs')));
    expect(newImpl, isNot(contains('UnimplementedError')));
    expect(newImpl, contains('remoteDataSource.getSongs()'));
    expect('@override'.allMatches(newImpl), hasLength(1));
  });

  test('replaceAllOnce never replaces a value it just inserted', () {
    expect(
      replaceAllOnce('player playerBloc', {'player': 'audio_player'}),
      'audio_player audio_playerBloc',
    );
    expect(
      replaceAllOnce('Songs SongsBloc', {'Songs': 'Tracks'}, wholeWords: true),
      'Tracks SongsBloc',
    );
  });
}
