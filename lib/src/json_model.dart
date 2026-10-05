/// Generates domain entities and data models from a sample JSON value.
library;

import 'package:flutter_clean_arch/src/generator.dart';
import 'package:flutter_clean_arch/src/naming.dart';

/// Field names that clash with members every entity already has.
const _memberClashes = {'props', 'stringify', 'hashCode', 'runtimeType'};

/// Dart keywords that cannot be field names.
const _keywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', //
  'class', 'const', 'continue', 'default', 'do', 'dynamic', 'else', 'enum',
  'export', 'extends', 'external', 'factory', 'false', 'final', 'finally',
  'for', 'get', 'if', 'implements', 'import', 'in', 'interface', 'is',
  'late', 'library', 'mixin', 'new', 'null', 'on', 'operator', 'part',
  'required', 'rethrow', 'return', 'set', 'static', 'super', 'switch',
  'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with',
  'yield',
};

final _isoDate = RegExp(
  r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$',
);

/// Type of a field inferred from the sample.
sealed class _Type {
  const _Type({required this.nullable});

  /// Whether the field can be `null`.
  final bool nullable;

  _Type asNullable();
}

/// `String`, `int`, `double`, `bool` or `dynamic`.
final class _Primitive extends _Type {
  const _Primitive(this.dart, {required super.nullable});

  final String dart;

  @override
  _Type asNullable() => _Primitive(dart, nullable: true);
}

final class _Date extends _Type {
  const _Date({required super.nullable});

  @override
  _Type asNullable() => const _Date(nullable: true);
}

final class _Object extends _Type {
  const _Object(this.cls, {required super.nullable});

  final _Class cls;

  @override
  _Type asNullable() => _Object(cls, nullable: true);
}

final class _List extends _Type {
  const _List(this.element, {required super.nullable});

  final _Type element;

  @override
  _Type asNullable() => _List(element, nullable: true);
}

class _Field {
  _Field(this.key, this.name, this.type);

  /// Key in the JSON.
  final String key;

  /// camelCase Dart name.
  final String name;

  _Type type;
}

class _Class {
  _Class(this.name);

  final FeatureName name;
  final fields = <_Field>[];
}

/// Entity and model files generated from a JSON sample.
///
/// [json] is the decoded sample (an object, or an array whose objects are
/// merged). The root class is [name]; nested objects become their own
/// classes, named after their key (singular for lists). With [nullable]
/// every field is nullable; otherwise only those whose sample is `null`,
/// or that are missing from some element of a list.
///
/// Paths are relative to the project, under
/// `lib/features/<feature>/domain/entities` and `…/data/models`.
List<RenderedFile> modelsFromJson({
  required Object? json,
  required String package,
  required FeatureName feature,
  required FeatureName name,
  required String source,
  bool nullable = false,
}) {
  final root = _rootObject(json);
  final classes = <String, _Class>{};
  _buildClass(name, [root], classes, parent: null, forceNullable: nullable);

  final base = 'lib/features/${feature.snake}';
  return [
    for (final cls in classes.values) ...[
      RenderedFile(
        '$base/domain/entities/${cls.name.snake}_entity.dart',
        _entity(cls, package, feature, source),
      ),
      RenderedFile(
        '$base/data/models/${cls.name.snake}_model.dart',
        _model(cls, package, feature, source),
      ),
    ],
  ];
}

Map<String, dynamic> _rootObject(Object? json) {
  if (json is Map<String, dynamic>) return json;
  if (json is List && json.isNotEmpty && json.every((e) => e is Map)) {
    return _merge(json.cast<Map<String, dynamic>>()).single;
  }
  throw const FormatException(
    'El JSON debe ser un objeto o una lista de objetos.',
  );
}

/// Merges the elements of a list of objects into one sample, so every key
/// that appears in some element is a field:
/// - nested objects are merged recursively and lists are concatenated;
/// - numbers become `double` if any of them has decimals;
/// - keys missing from some element, or `null` in some element, are
///   wrapped in a [_Missing] so the field is nullable.
List<Map<String, dynamic>> _merge(List<Map<String, dynamic>> objects) {
  final keys = <String>{for (final o in objects) ...o.keys};
  final merged = <String, dynamic>{};
  for (final key in keys) {
    final values = [
      for (final o in objects)
        if (o.containsKey(key)) _unwrap(o[key]),
    ];
    final nullable =
        values.length < objects.length ||
        values.contains(null) ||
        objects.any((o) => o[key] is _Missing);
    final present = values.whereType<Object>().toList();

    final Object? value;
    if (present.isEmpty) {
      value = null;
    } else if (present.every((v) => v is Map<String, dynamic>)) {
      value = _merge(present.cast<Map<String, dynamic>>()).single;
    } else if (present.every((v) => v is List)) {
      value = [for (final v in present) ...v as List];
    } else if (present.every((v) => v is num)) {
      value = present.firstWhere((v) => v is double, orElse: () => present[0]);
    } else {
      value = present.first;
    }
    merged[key] = nullable ? _Missing(value) : value;
  }
  return [merged];
}

Object? _unwrap(Object? value) => value is _Missing ? value.value : value;

/// Value of a key that is missing or `null` in some element of a list.
class _Missing {
  const _Missing(this.value);

  final Object? value;
}

_Class _buildClass(
  FeatureName name,
  List<Map<String, dynamic>> samples,
  Map<String, _Class> classes, {
  required _Class? parent,
  required bool forceNullable,
}) {
  final sample = samples.length == 1 ? samples.single : _merge(samples).single;

  // Same name as an existing class: reuse it if it has the same keys,
  // otherwise prefix the parent's name.
  var className = name;
  final existing = classes[className.snake];
  if (existing != null) {
    final sameKeys =
        existing.fields.map((f) => f.key).toSet().containsAll(sample.keys) &&
        sample.keys.toSet().containsAll(existing.fields.map((f) => f.key));
    if (sameKeys) return existing;
    className = FeatureName.parse(
      '${parent?.name.snake ?? 'root'}_${name.snake}',
      allowTaken: true,
    );
  }

  final cls = _Class(className);
  classes[className.snake] = cls;
  sample.forEach((key, value) {
    final missing = value is _Missing;
    final raw = missing ? value.value : value;
    var type = _typeOf(key, raw, cls, classes, forceNullable: forceNullable);
    if (missing || forceNullable) type = type.asNullable();
    cls.fields.add(_Field(key, _fieldName(key), type));
  });
  return cls;
}

_Type _typeOf(
  String key,
  Object? value,
  _Class parent,
  Map<String, _Class> classes, {
  required bool forceNullable,
}) {
  switch (value) {
    case null:
      return const _Primitive('dynamic', nullable: true);
    case String()
        when _isoDate.hasMatch(value) && DateTime.tryParse(value) != null:
      return const _Date(nullable: false);
    case String():
      return const _Primitive('String', nullable: false);
    case int():
      return const _Primitive('int', nullable: false);
    case double():
      return const _Primitive('double', nullable: false);
    case bool():
      return const _Primitive('bool', nullable: false);
    case Map<String, dynamic>():
      return _Object(
        _buildClass(
          _className(key),
          [value],
          classes,
          parent: parent,
          forceNullable: forceNullable,
        ),
        nullable: false,
      );
    case List():
      return _List(
        _elementType(key, value, parent, classes, forceNullable),
        nullable: false,
      );
    default:
      return const _Primitive('dynamic', nullable: true);
  }
}

_Type _elementType(
  String key,
  List<dynamic> list,
  _Class parent,
  Map<String, _Class> classes,
  bool forceNullable,
) {
  final values = list.where((e) => e != null).toList();
  if (values.isEmpty) return const _Primitive('dynamic', nullable: true);
  if (values.every((e) => e is Map<String, dynamic>)) {
    return _Object(
      _buildClass(
        _className(key, singular: true),
        values.cast<Map<String, dynamic>>(),
        classes,
        parent: parent,
        forceNullable: forceNullable,
      ),
      nullable: false,
    );
  }
  if (values.every((e) => e is num) && values.any((e) => e is double)) {
    return const _Primitive('double', nullable: false);
  }
  final first = _typeOf(
    key,
    values.first,
    parent,
    classes,
    forceNullable: forceNullable,
  );
  final sameKind = values.every(
    (e) => e.runtimeType == values.first.runtimeType,
  );
  return sameKind && first is! _List
      ? first
      : const _Primitive('dynamic', nullable: true);
}

/// Class name for the JSON [key]: `album` → `Album`, and with [singular]
/// `songs` → `Song`, `categories` → `Category`.
FeatureName _className(String key, {bool singular = false}) {
  final words = splitWords(key.replaceAll(RegExp('[^A-Za-z0-9_ -]'), ' '));
  if (words.isEmpty) return FeatureName.parse('item', allowTaken: true);
  if (singular) words[words.length - 1] = _singular(words.last);
  try {
    return FeatureName.parse(words.join('_'), allowTaken: true);
  } on FormatException {
    return FeatureName.parse('item_${words.join('_')}', allowTaken: true);
  }
}

String _singular(String word) {
  if (word.length > 3 && word.endsWith('ies')) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (word.length > 3 && word.endsWith('ses')) {
    return word.substring(0, word.length - 2);
  }
  if (word.length > 1 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return '${word}Item';
}

/// camelCase field name for the JSON [key], avoiding keywords and the
/// members of `Equatable`.
String _fieldName(String key) {
  final words = splitWords(key.replaceAll(RegExp('[^A-Za-z0-9_ -]'), ' '));
  var name = words.isEmpty
      ? 'field'
      : words.first + words.skip(1).map(_capitalize).join();
  if (RegExp('^[0-9]').hasMatch(name)) name = 'field${_capitalize(name)}';
  if (_keywords.contains(name) || _memberClashes.contains(name)) {
    name = '${name}Value';
  }
  return name;
}

String _capitalize(String w) =>
    w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';

// ── Code ────────────────────────────────────────────────────

String _entityType(_Type type) {
  final base = switch (type) {
    _Primitive(:final dart) => dart,
    _Date() => 'DateTime',
    _Object(:final cls) => '${cls.name.pascal}Entity',
    _List(:final element) => 'List<${_entityType(element)}>',
  };
  final isDynamic = type is _Primitive && type.dart == 'dynamic';
  return type.nullable && !isDynamic ? '$base?' : base;
}

/// Expression that reads [expr] (a JSON value) as [type].
String _read(_Type type, String expr, [int depth = 0]) {
  final n = type.nullable;
  switch (type) {
    case _Primitive(dart: 'dynamic'):
      return expr;
    case _Primitive(dart: 'double'):
      return n ? '($expr as num?)?.toDouble()' : '($expr as num).toDouble()';
    case _Primitive(:final dart):
      return '$expr as $dart${n ? '?' : ''}';
    case _Date():
      return n
          ? '$expr == null ? null : DateTime.parse($expr as String)'
          : 'DateTime.parse($expr as String)';
    case _Object(:final cls):
      final call =
          '${cls.name.pascal}Model.fromJson($expr as Map<String, dynamic>)';
      return n ? '$expr == null ? null : $call' : call;
    case _List(:final element):
      final e = depth == 0 ? 'e' : 'e$depth';
      final cast = '$expr as List<dynamic>${n ? '?' : ''}';
      if (element is _Primitive && element.dart == 'dynamic') return cast;
      return '($cast)${n ? '?' : ''}.map(($e) => '
          '${_read(element, e, depth + 1)}).toList()';
  }
}

/// Expression that converts the field [expr] of [type] to JSON.
String _write(_Type type, String expr, [int depth = 0]) {
  final n = type.nullable;
  switch (type) {
    case _Primitive():
      return expr;
    case _Date():
      return '$expr${n ? '?' : ''}.toIso8601String()';
    case _Object(:final cls):
      final model = '${cls.name.pascal}Model';
      return n
          ? '$expr == null ? null : $model.fromEntity($expr!).toJson()'
          : '$model.fromEntity($expr).toJson()';
    case _List(:final element):
      if (element is _Primitive) return expr;
      final e = depth == 0 ? 'e' : 'e$depth';
      return '$expr${n ? '?' : ''}.map(($e) => '
          '${_write(element, e, depth + 1)}).toList()';
  }
}

/// Whether [field] is a `required` constructor parameter.
bool _isRequired(_Field field) => switch (field.type) {
  _Primitive(dart: 'dynamic') => false,
  final type => !type.nullable,
};

/// [fields] with the required ones first, otherwise in JSON order.
List<_Field> _requiredFirst(List<_Field> fields) => [
  ...fields.where(_isRequired),
  ...fields.where((f) => !_isRequired(f)),
];

bool _hasNested(_Class cls) => cls.fields.any((f) => _nests(f.type));

bool _nests(_Type type) => switch (type) {
  _Object() => true,
  _List(:final element) => _nests(element),
  _ => false,
};

String _header(String title, String line2, String source) =>
    '''
// ─────────────────────────────────────────────────────────────
// $title
// $line2
// Generated from $source by `flutter_clean_arch model`.
// ─────────────────────────────────────────────────────────────
''';

String _entity(_Class cls, String package, FeatureName f, String source) {
  final name = '${cls.name.pascal}Entity';
  final b = StringBuffer()
    ..writeln(
      _header(name, 'Business object of the ${f.lowerWords} feature.', source),
    );
  if (_hasNested(cls)) {
    b.writeln(
      "import 'package:$package/features/${f.snake}/domain/domain.dart';",
    );
  }
  b
    ..writeln("import 'package:equatable/equatable.dart';")
    ..writeln()
    ..writeln('/// ${cls.name.title} data as the domain layer sees it.')
    ..writeln('class $name extends Equatable {')
    ..writeln('  /// Creates the ${cls.name.lowerWords} entity.');
  if (cls.fields.isEmpty) {
    b.writeln('  const $name();');
  } else {
    b.writeln('  const $name({');
    for (final field in _requiredFirst(cls.fields)) {
      final required = _isRequired(field) ? 'required ' : '';
      b.writeln('    ${required}this.${field.name},');
    }
    b.writeln('  });');
  }
  for (final field in cls.fields) {
    b
      ..writeln()
      ..writeln('  /// Value of `${field.key}` in the JSON.')
      ..writeln('  final ${_entityType(field.type)} ${field.name};');
  }
  final props = cls.fields.map((f) => f.name).join(', ');
  b
    ..writeln()
    ..writeln('  @override')
    ..writeln('  List<Object?> get props => [$props];')
    ..writeln('}');
  return b.toString();
}

String _model(_Class cls, String package, FeatureName f, String source) {
  final name = '${cls.name.pascal}Model';
  final entity = '${cls.name.pascal}Entity';
  final b = StringBuffer()
    ..writeln(
      _header(name, 'JSON serialization of $entity.', source),
    );
  if (_hasNested(cls)) {
    b.writeln(
      "import 'package:$package/features/${f.snake}/data/data.dart';",
    );
  }
  b
    ..writeln(
      "import 'package:$package/features/${f.snake}/domain/domain.dart';",
    )
    ..writeln()
    ..writeln('/// [$entity] with JSON serialization for the API and storage.')
    ..writeln('class $name extends $entity {')
    ..writeln('  /// Creates the ${cls.name.lowerWords} model.');
  if (cls.fields.isEmpty) {
    b.writeln('  const $name();');
  } else {
    b.writeln('  const $name({');
    for (final field in _requiredFirst(cls.fields)) {
      final required = _isRequired(field) ? 'required ' : '';
      b.writeln('    ${required}super.${field.name},');
    }
    b.writeln('  });');
  }

  b
    ..writeln()
    ..writeln('  /// Creates a [$name] from a JSON map.')
    ..writeln('  factory $name.fromJson(Map<String, dynamic> json) {')
    ..writeln('    return $name(');
  for (final field in cls.fields) {
    b.writeln(
      "      ${field.name}: ${_read(field.type, "json['${field.key}']")},",
    );
  }
  b
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  /// Creates a [$name] with the values of [entity].')
    ..writeln('  factory $name.fromEntity($entity entity) {')
    ..writeln('    return $name(');
  for (final field in cls.fields) {
    b.writeln('      ${field.name}: entity.${field.name},');
  }
  b
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  /// Converts this model into a JSON map.')
    ..writeln('  Map<String, dynamic> toJson() {')
    ..writeln('    return {');
  for (final field in cls.fields) {
    b.writeln("      '${field.key}': ${_write(field.type, field.name)},");
  }
  b
    ..writeln('    };')
    ..writeln('  }')
    ..writeln('}');
  return b.toString();
}
