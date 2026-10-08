import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:test/test.dart';

void main() {
  late TemplateGenerator generator;

  setUpAll(() async => generator = await TemplateGenerator.locate());

  final vars = {
    'package': 'demo_app',
    'todoTag': 'demo-app',
    'feature': 'songs',
    'Feature': 'Songs',
    'name': 'song_detail',
    'Name': 'SongDetail',
    'nameCamel': 'songDetail',
    'nameTitle': 'Song detail',
    'nameWords': 'song detail',
  };

  for (final (template, file, contents) in [
    (
      'test_page',
      'song_detail_page_test.dart',
      'pumpApp(const SongDetailPage())',
    ),
    (
      'test_page_bloc',
      'song_detail_page_test.dart',
      'child: const SongDetailView()',
    ),
    (
      'test_bloc',
      'song_detail_bloc_test.dart',
      'bloc.add(const SongDetailStarted())',
    ),
    ('test_cubit', 'song_detail_cubit_test.dart', 'cubit.load()'),
  ]) {
    test('$template renders $file', () {
      final rendered = generator.render(template, vars).single;

      expect(rendered.relativePath, 'song_detail/$file');
      expect(rendered.content, contains(contents));
      expect(rendered.content, isNot(contains('{{')));
    });
  }

  test('sampleValue knows the common types', () {
    expect(sampleValue('Unit'), 'unit');
    expect(sampleValue('String'), "'value'");
    expect(sampleValue('List<SongEntity>'), '<SongEntity>[]');
    expect(sampleValue('Map<String, int>'), '<String, int>{}');
    expect(sampleValue('SongEntity?'), 'null');
    expect(sampleValue('NoParams'), 'NoParams()');
    expect(sampleValue('SearchParams'), isNull);
  });

  group('usecaseTest', () {
    final feature = FeatureName.parse('songs');
    final item = FeatureName.parse('search_songs');

    String render(String returns, String params) => usecaseTest(
      package: 'demo_app',
      todoTag: 'demo-app',
      feature: feature,
      item: item,
      returns: returns,
      params: params,
    );

    test('with known types tests success and failure', () {
      final code = render('List<SongsEntity>', 'String');

      expect(
        code,
        allOf(
          contains("const params = 'value';"),
          contains('const result = <SongsEntity>[];'),
          contains('repository.searchSongs(params)'),
          contains('const Right<Failure, List<SongsEntity>>(result)'),
          isNot(contains('skip:')),
        ),
      );
    });

    test('NoParams calls the repository without arguments', () {
      final code = render('Unit', 'NoParams');

      expect(code, contains('const params = NoParams();'));
      expect(code, contains('repository.searchSongs()'));
    });

    test('project classes are skipped with a TODO instead of failing', () {
      final code = render('SongsEntity', 'SearchParams');

      expect(code, contains('late SearchParams params;'));
      expect(code, contains("skip: 'TODO(demo-app): crea un valor de"));
    });
  });
}
