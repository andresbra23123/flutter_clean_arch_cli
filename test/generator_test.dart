import 'dart:io';

import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late TemplateGenerator generator;

  setUpAll(() async => generator = await TemplateGenerator.locate());

  final featureVars = {
    'package': 'demo_app',
    'todoTag': 'demo-app',
    'name': 'user_profile',
    'Name': 'UserProfile',
    'nameCamel': 'userProfile',
    'nameTitle': 'User profile',
    'nameWords': 'user profile',
  };

  void expectClean(List<RenderedFile> files) {
    for (final f in files) {
      expect(f.content, isNot(contains('{{')), reason: f.relativePath);
      expect(f.relativePath, isNot(contains('__name__')));
      expect(f.relativePath, isNot(endsWith('.tmpl')));
    }
  }

  /// Every folder that holds Dart files has its own barrel file, except the
  /// `lib/` root (entry points).
  void expectBarrels(Set<String> paths) {
    final dartDirs = paths
        .where((path) => path.endsWith('.dart'))
        .map(p.posix.dirname)
        .where((dir) => dir != 'lib')
        .toSet();
    for (final dir in dartDirs) {
      expect(
        paths,
        contains('$dir/${p.posix.basename(dir)}.dart'),
        reason: 'missing barrel in $dir',
      );
    }
  }

  test('init renders the base structure without leftovers', () {
    final files = generator.render('init', {
      'package': 'demo_app',
      'todoTag': 'demo-app',
      'appTitle': 'Demo App',
    });
    final paths = files.map((f) => f.relativePath).toSet();

    expect(
      paths,
      containsAll([
        'lib/app/pages/app.dart',
        'lib/app/pages/pages.dart',
        'lib/bootstrap.dart',
        'lib/main_development.dart',
        'lib/core/di/injection_container.dart',
        'lib/core/router/router.dart',
        'lib/core/router/app_router.dart',
        'lib/core/router/go_router_refresh_stream.dart',
        'lib/core/mixings/mixings.dart',
        'lib/core/mixings/validator.dart',
        'lib/core/l10n/arb/app_en.arb',
        'lib/features/home/home.dart',
        'lib/features/home/presentation/pages/pages.dart',
        'lib/features/home/presentation/pages/home/home.dart',
        'lib/features/home/presentation/pages/home/home_page.dart',
        'lib/features/home/presentation/pages/home/components/components.dart',
        'l10n.yaml',
        'analysis_options.yaml',
        '.vscode/launch.json',
      ]),
    );
    expect(paths.any((p) => p.contains('features/auth')), isFalse);
    expectClean(files);
    expectBarrels(paths);
  });

  test('feature renders 34 files under lib/features/<name>', () {
    final files = generator.render(
      'feature',
      featureVars,
      outputPrefix: 'lib/features',
    );
    final paths = files.map((f) => f.relativePath).toSet();

    expect(files, hasLength(34));
    expect(
      paths,
      containsAll([
        'lib/features/user_profile/user_profile.dart',
        'lib/features/user_profile/user_profile_injection.dart',
        'lib/features/user_profile/domain/usecases/get_user_profile.dart',
        'lib/features/user_profile/presentation/bloc/user_profile/user_profile_bloc.dart',
        'lib/features/user_profile/presentation/bloc/user_profile/user_profile.dart',
        'lib/features/user_profile/data/datasources/remote/user_profile_remote_datasource_inter.dart',
        'lib/features/user_profile/data/datasources/datasources.dart',
        'lib/features/user_profile/presentation/bloc/bloc.dart',
        'lib/features/user_profile/presentation/pages/user_profile/user_profile_page.dart',
        'lib/features/user_profile/presentation/pages/user_profile/components/components.dart',
        'lib/features/user_profile/presentation/pages/user_profile/components/user_profile_error_view.dart',
      ]),
    );
    expectClean(files);

    expectBarrels(paths);

    final bloc = files.firstWhere((f) => f.relativePath.endsWith('_bloc.dart'));
    expect(bloc.content, contains('class UserProfileBloc'));
    expect(bloc.content, contains("part 'user_profile_event.dart';"));

    // Markers used by the `bloc` and `usecase` commands.
    String content(String suffix) =>
        files.firstWhere((f) => f.relativePath.endsWith(suffix)).content;
    expect(
      content('_injection.dart'),
      allOf(contains(Markers.blocs), contains(Markers.usecases)),
    );
    expect(
      content('_repository_inter.dart'),
      contains(Markers.repositoryMethods),
    );
    expect(
      content('_repository_impl.dart'),
      contains(Markers.repositoryMethods),
    );
  });

  group('item templates', () {
    final itemVars = {
      'package': 'demo_app',
      'todoTag': 'demo-app',
      'feature': 'songs',
      'Feature': 'Songs',
      'name': 'song_detail',
      'Name': 'SongDetail',
      'nameCamel': 'songDetail',
      'nameTitle': 'Song detail',
      'nameWords': 'song detail',
      'returns': 'Unit',
      'params': 'NoParams',
      'callArgs': '',
    };

    for (final (dir, count) in [
      ('page', 3),
      ('page_bloc', 1),
      ('bloc', 4),
      ('cubit', 3),
      ('usecase', 1),
    ]) {
      test('$dir renders $count files without leftovers', () {
        final files = generator.render(dir, itemVars, outputPrefix: 'out');

        expect(files, hasLength(count));
        expectClean(files);
        if (dir != 'usecase' && dir != 'page_bloc') {
          expectBarrels(files.map((f) => f.relativePath).toSet());
        }
      });
    }

    test('page has its folder, page file and components barrel', () {
      final paths = generator
          .render('page', itemVars, outputPrefix: 'pages')
          .map((f) => f.relativePath);

      expect(
        paths,
        unorderedEquals([
          'pages/song_detail/song_detail.dart',
          'pages/song_detail/song_detail_page.dart',
          'pages/song_detail/components/components.dart',
        ]),
      );
    });

    test('component renders one StatelessWidget', () {
      final file = generator.render('component', {
        ...itemVars,
        'kindDescription': 'Component of the page.',
      }).single;

      expect(file.relativePath, 'song_detail.dart');
      expect(
        file.content,
        contains('class SongDetail extends StatelessWidget'),
      );
      expectClean([file]);
    });

    test('usecase calls the repository method', () {
      final usecase = generator.render('usecase', itemVars).single;

      expect(usecase.relativePath, 'song_detail.dart');
      expect(
        usecase.content,
        allOf(
          contains('class SongDetailUseCaseImpl'),
          contains('implements UseCaseInter<Unit, NoParams>'),
          contains('repository.songDetail()'),
        ),
      );
    });
  });

  test('test_feature renders the 4 tests of a feature', () {
    final files = generator.render(
      'test_feature',
      featureVars,
      outputPrefix: 'test/features',
    );

    const root = 'test/features/user_profile';
    expect(
      files.map((f) => f.relativePath),
      unorderedEquals([
        '$root/domain/usecases/get_user_profile_test.dart',
        '$root/data/repositories/user_profile_repository_impl_test.dart',
        '$root/presentation/bloc/user_profile/user_profile_bloc_test.dart',
        '$root/presentation/pages/user_profile/user_profile_page_test.dart',
      ]),
    );
    expectClean(files);
  });

  test('auth renders the feature, its tests and the Firebase barrel', () {
    final vars = {
      'package': 'demo_app',
      'todoTag': 'demo-app',
      'appTitle': 'Demo App',
    };
    final files = generator.render('auth', vars);
    final paths = files.map((f) => f.relativePath).toSet();

    expect(
      paths,
      containsAll([
        'lib/features/auth/auth.dart',
        'lib/features/auth/auth_injection.dart',
        'lib/features/auth/presentation/pages/login/login_page.dart',
        'lib/core/firebase/firebase_flavor_options.dart',
        'test/features/auth/presentation/bloc/login/login_bloc_test.dart',
      ]),
    );
    expectClean(files);
    expectBarrels(paths.where((path) => path.startsWith('lib/')).toSet());

    final arbs = generator.render('auth_l10n', vars);
    expect(arbs.map((f) => f.relativePath), ['app_en.arb', 'app_es.arb']);
    expectClean(arbs);
  });

  test('writeAll creates the files on disk', () {
    final dir = Directory.systemTemp.createTempSync('fca_gen_');
    addTearDown(() => dir.deleteSync(recursive: true));

    writeAll(dir.path, const [RenderedFile('a/b/c.dart', 'x')]);

    expect(File(p.join(dir.path, 'a/b/c.dart')).readAsStringSync(), 'x');
  });
}
