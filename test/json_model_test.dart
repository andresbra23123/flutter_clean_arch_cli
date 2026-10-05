import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:test/test.dart';

void main() {
  final feature = FeatureName.parse('songs');
  final name = FeatureName.parse('song');

  Map<String, String> render(Object? json, {bool nullable = false}) => {
    for (final f in modelsFromJson(
      json: json,
      package: 'demo_app',
      feature: feature,
      name: name,
      source: 'song.json',
      nullable: nullable,
    ))
      f.relativePath: f.content,
  };

  const entity = 'lib/features/songs/domain/entities/song_entity.dart';
  const model = 'lib/features/songs/data/models/song_model.dart';

  test('maps primitives, dates and keys to typed fields', () {
    final files = render({
      'id': 7,
      'title': 'Blue Train',
      'rating': 4.5,
      'explicit': false,
      'released_at': '1957-09-15',
      'class': 'A',
    });

    expect(files.keys, unorderedEquals([entity, model]));
    expect(
      files[entity],
      allOf(
        contains('class SongEntity extends Equatable'),
        contains('final int id;'),
        contains('final String title;'),
        contains('final double rating;'),
        contains('final bool explicit;'),
        contains('final DateTime releasedAt;'),
        // Keywords get a suffix.
        contains('final String classValue;'),
      ),
    );
    expect(
      files[model],
      allOf(
        contains("releasedAt: DateTime.parse(json['released_at'] as String)"),
        contains("rating: (json['rating'] as num).toDouble()"),
        contains("'released_at': releasedAt.toIso8601String()"),
        contains("'class': classValue"),
        contains('factory SongModel.fromEntity(SongEntity entity)'),
      ),
    );
  });

  test('nested objects and lists of objects get their own classes', () {
    final files = render({
      'album': {'id': 'a1'},
      'artists': [
        {'id': 'ar1'},
      ],
      'genres': ['jazz'],
    });

    expect(
      files.keys,
      containsAll([
        'lib/features/songs/domain/entities/album_entity.dart',
        'lib/features/songs/data/models/album_model.dart',
        // Singular of the list key.
        'lib/features/songs/domain/entities/artist_entity.dart',
      ]),
    );
    expect(
      files[entity],
      allOf(
        contains('final AlbumEntity album;'),
        contains('final List<ArtistEntity> artists;'),
        contains('final List<String> genres;'),
        contains(
          "import 'package:demo_app/features/songs/domain/domain.dart';",
        ),
      ),
    );
    expect(
      files[model],
      allOf(
        contains("AlbumModel.fromJson(json['album'] as Map<String, dynamic>)"),
        contains("'album': AlbumModel.fromEntity(album).toJson()"),
        contains('ArtistModel.fromEntity(e).toJson()'),
      ),
    );
  });

  test('a root list merges its elements: missing or null keys are '
      'nullable, mixed numbers are double', () {
    final files = render([
      {'id': 1, 'cover': null, 'rating': 4},
      {'id': 2, 'cover': 'x.png', 'rating': 4.5, 'lyrics': '…'},
    ]);

    expect(
      files[entity],
      allOf(
        contains('final int id;'),
        contains('final String? cover;'),
        contains('final double rating;'),
        contains('final String? lyrics;'),
        // Required parameters go first.
        matches(RegExp(r'required this\.rating,\s+this\.cover')),
      ),
    );
  });

  test('--nullable makes every field nullable', () {
    final files = render({'id': 1}, nullable: true);

    expect(files[entity], contains('final int? id;'));
    expect(files[model], contains("id: json['id'] as int?"));
  });

  test('rejects JSON that is not an object or a list of objects', () {
    expect(() => render([1, 2]), throwsFormatException);
    expect(() => render('text'), throwsFormatException);
  });
}
