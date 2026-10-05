/// Converts names between the cases the templates need.
library;

/// Dart reserved words and built-in identifiers that cannot be used as
/// a feature name.
const _reserved = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Feature names that would clash with folders created by `init`.
const _taken = {'app', 'core', 'home'};

/// Splits [input] into lowercase words.
///
/// Accepts snake_case, kebab-case, camelCase, PascalCase and spaces:
/// `UserProfile`, `user-profile` and `user_profile` all give
/// `['user', 'profile']`.
List<String> splitWords(String input) {
  final spaced = input
      .trim()
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll(RegExp(r'[_\-\s]+'), ' ')
      .trim();
  if (spaced.isEmpty) return const [];
  return spaced.split(' ').map((w) => w.toLowerCase()).toList();
}

String _capitalize(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

/// Every case of a feature name used by the templates.
class FeatureName {
  const FeatureName._(this.words);

  /// Parses and validates [input].
  ///
  /// With [allowTaken], names used by the base structure (such as `home`)
  /// are accepted: useful for pages, BLoCs and use cases, or to target an
  /// existing feature.
  ///
  /// Throws a [FormatException] with a readable message if the name is
  /// not valid.
  factory FeatureName.parse(String input, {bool allowTaken = false}) {
    final words = splitWords(input);
    final snake = words.join('_');
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(snake)) {
      throw FormatException(
        '"$input" no es un nombre válido. Usa letras, números y guiones '
        'bajos, empezando por una letra (por ejemplo: songs, user_profile).',
      );
    }
    if (_reserved.contains(snake)) {
      throw FormatException('"$snake" es una palabra reservada de Dart.');
    }
    if (!allowTaken && _taken.contains(snake)) {
      throw FormatException('"$snake" ya lo usa la estructura base.');
    }
    return FeatureName._(words);
  }

  /// Lowercase words, e.g. `['user', 'profile']`.
  final List<String> words;

  /// `user_profile`: files, folders and route paths.
  String get snake => words.join('_');

  /// `UserProfile`: class names.
  String get pascal => words.map(_capitalize).join();

  /// `userProfile`: members such as `AppRoutes.userProfile`.
  String get camel {
    final p = pascal;
    return '${p[0].toLowerCase()}${p.substring(1)}';
  }

  /// `User profile`: visible titles.
  String get title => _capitalize(words.join(' '));

  /// `user profile`: prose in comments.
  String get lowerWords => words.join(' ');
}

/// Tag for `TODO(tag):` comments: the package name with hyphens, because
/// the `flutter_style_todos` lint does not accept underscores
/// (`demo_app` → `demo-app`).
String todoTagFromPackage(String package) => package.replaceAll('_', '-');

/// Visible app name from a package name: `demo_app` → `Demo App`.
String appTitleFromPackage(String package) =>
    splitWords(package).map(_capitalize).join(' ');
